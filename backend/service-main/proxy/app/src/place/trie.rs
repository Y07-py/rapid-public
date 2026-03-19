use std::collections::HashSet;
use std::sync::Arc;
use tokio;
use tokio::sync::RwLock;

use crate::place::{self, metrics};

#[derive(Debug, Clone)]
pub struct QuadTreeInsertMessage {
    pub places: Vec<place::object::GooglePlacesSearchResponsePlace>,
    pub zoom: usize,
}

impl QuadTreeInsertMessage {
    pub fn new(places: Vec<place::object::GooglePlacesSearchResponsePlace>, zoom: usize) -> Self {
        Self { places, zoom }
    }
}

#[derive(Debug, Clone)]
pub struct QuadNode {
    child: [Option<Box<QuadNode>>; 4],
    values: HashSet<place::object::GooglePlaceSearchPlaceId>,
    pt_bit_mask: [u64; 4],
    terminal: bool,
    total_size: usize,
}

impl QuadNode {
    pub fn new(value: Option<place::object::GooglePlaceSearchPlaceId>, terminal: bool) -> Self {
        let mut values: HashSet<place::object::GooglePlaceSearchPlaceId> = HashSet::new();

        if let Some(value) = value {
            values.insert(value);
        }

        Self {
            child: [None, None, None, None],
            values,
            pt_bit_mask: [0, 0, 0, 0],
            terminal,
            total_size: 0,
        }
    }

    pub fn set_terminal(&mut self, terminal: bool) {
        self.terminal = terminal;
    }

    pub fn set_value(&mut self, value: place::object::GooglePlaceSearchPlaceId) {
        self.values.insert(value);
    }

    pub fn get_values(&self) -> HashSet<place::object::GooglePlaceSearchPlaceId> {
        self.values.clone()
    }

    pub fn increment_total_size(&mut self) {
        self.total_size += 1;
    }

    pub fn is_terminal(&self) -> bool {
        self.terminal
    }

    pub fn apply_attribute_mask(&mut self, mask: &[u64; 4]) {
        for i in 0..4 {
            self.pt_bit_mask[i] |= mask[i];
        }
    }

    pub fn match_attribute_mask(&self, query_masks: &[[u64; 4]]) -> bool {
        // Return true if the node contains AT LEAST ONE of the queried types
        for mask in query_masks {
            let mut matches = true;
            for i in 0..4 {
                if (self.pt_bit_mask[i] & mask[i]) != mask[i] {
                    matches = false;
                    break;
                }
            }
            if matches {
                return true;
            }
        }
        false
    }
}

#[derive(Debug, Clone)]
pub struct QuadNodeTrieTree {
    root: Box<QuadNode>,
    key_length: u32,
    event_sender: tokio::sync::mpsc::Sender<QuadTreeInsertMessage>,
}

impl QuadNodeTrieTree {
    pub fn new(key_length: u32) -> Arc<RwLock<Self>> {
        let root = Box::new(QuadNode::new(None, false));
        let (tx, mut rx) = tokio::sync::mpsc::channel::<QuadTreeInsertMessage>(1024);

        let trie_tree = Arc::new(RwLock::new(Self {
            root,
            key_length,
            event_sender: tx,
        }));

        let trie_tree_inner = trie_tree.clone();

        tokio::spawn(async move {
            // When receive event of insert, send to evnet receiver.
            while let Some(msg) = rx.recv().await {
                let mut guard = trie_tree_inner.write().await;
                guard.multiple_insert(msg.places, msg.zoom);
            }
        });

        trie_tree
    }

    pub async fn send_insert_event(
        &self,
        places: Vec<place::object::GooglePlacesSearchResponsePlace>,
        zoom: usize,
    ) {
        let sender = self.event_sender.clone();
        let insert_msg = QuadTreeInsertMessage::new(places, zoom);

        if let Err(e) = sender.send(insert_msg).await {
            eprintln!("Failed to insert place id in quqd node tree. {:?}", e);
        }
    }

    fn multiple_insert(
        &mut self,
        places: Vec<place::object::GooglePlacesSearchResponsePlace>,
        zoom: usize,
    ) {
        for place in places.into_iter() {
            // Place id will be expired after 24 hours.
            let place_id =
                place::object::GooglePlaceSearchPlaceId::new(place.get_place_id().unwrap());
            let place_types = place.get_types().unwrap_or(Vec::new());

            // Get place coordinate.
            let latlng = place.get_latlng().unwrap();

            // Compute quadkeys in place coordinate.
            let key = place::metrics::compute_quadkeys(
                latlng.get_lon().unwrap(),
                latlng.get_lat().unwrap(),
                zoom,
            );

            self.insert(key, place_id, place_types);
        }
    }

    fn insert(
        &mut self,
        quadkeys: String,
        place_id: place::object::GooglePlaceSearchPlaceId,
        place_types: Vec<place::object::GooglePlaceType>,
    ) {
        // This function for storing placeid corresponding to computed quadkeys on a Trie tree.
        // PlaceId is stored at the terminal node corresponding to the end of quadkeys.

        // Compute blume hash. this hash is using for blume filter.
        let mut blume_mask = [0u64; 4];
        for t in &place_types {
            let indices = metrics::compute_blume_hash(t, 3, 256);
            for idx in indices {
                blume_mask[idx / 64] |= 1 << (idx % 64);
            }
        }

        // Check whether this specific place_id already exists at the terminal node.
        {
            let mut node = &*self.root;
            let mut reachable = true;
            for c in quadkeys.chars() {
                let child_idx = c.to_digit(10).unwrap() as usize;
                if let Some(child) = node.child[child_idx].as_ref() {
                    node = &**child;
                } else {
                    reachable = false;
                    break;
                }
            }
            if reachable && node.is_terminal() && node.get_values().contains(&place_id) {
                return;
            }
        }

        let mut target_node = &mut *self.root;
        target_node.apply_attribute_mask(&blume_mask);
        for c in quadkeys.chars() {
            let child_idx = c.to_digit(10).unwrap() as usize;

            // Check whether exit quad node.
            if target_node.child[child_idx].is_none() {
                target_node.child[child_idx] = Some(Box::new(QuadNode::new(None, false)));
            }

            target_node.increment_total_size();
            target_node = target_node.child[child_idx].as_mut().unwrap();
            target_node.apply_attribute_mask(&blume_mask);
        }

        // Store place id in edge node.
        target_node.set_value(place_id);
        target_node.set_terminal(true);
        target_node.increment_total_size();
    }

    pub fn tile_has_data(&self, prefix: &str) -> bool {
        // Traverses the trie to the given prefix. Returns true if the node is reachable
        // AND is terminal (indicating the tile has been searched, even if 0 results).
        let mut node = &*self.root;
        for c in prefix.chars() {
            let child_idx = c.to_digit(10).unwrap() as usize;
            if let Some(child) = node.child[child_idx].as_ref() {
                node = &**child;
            } else {
                return false;
            }
        }
        node.is_terminal()
    }

    pub fn mark_tile_searched(&mut self, quadkey_prefix: &str) {
        // Creates a node path to the prefix and marks the terminal node.
        // Does NOT increment total_size (no places added).
        // This prevents re-querying tiles that returned 0 results.
        let mut target_node = &mut *self.root;
        for c in quadkey_prefix.chars() {
            let child_idx = c.to_digit(10).unwrap() as usize;
            if target_node.child[child_idx].is_none() {
                target_node.child[child_idx] = Some(Box::new(QuadNode::new(None, false)));
            }
            target_node = target_node.child[child_idx].as_mut().unwrap();
        }
        target_node.set_terminal(true);
    }

    pub fn get(
        &self,
        quadkeys: String,
        place_types: Option<&Vec<place::object::GooglePlaceType>>,
    ) -> Option<HashSet<place::object::GooglePlaceSearchPlaceId>> {
        // This function retrieves all place ids contained within the nodes of
        // the given quadkyes, as well as all place ids contained within the
        // terminal child nodes of the keys.

        // Compute blume masks for blume filter.
        let query_masks: Option<Vec<[u64; 4]>> = match place_types {
            Some(types) if !types.is_empty() => {
                let mut masks = Vec::new();
                for t in types {
                    let mut mask = [0u64; 4];
                    let indices = metrics::compute_blume_hash(t, 3, 256);
                    for idx in indices {
                        mask[idx / 64] |= 1 << (idx % 64);
                    }
                    masks.push(mask);
                }
                Some(masks)
            }
            _ => None,
        };

        let mut placeids: HashSet<place::object::GooglePlaceSearchPlaceId> = HashSet::new();
        let mut target_node = &*self.root;
        for c in quadkeys.chars() {
            let child_idx = c.to_digit(10).unwrap() as usize;
            if let Some(child) = target_node.child[child_idx].as_ref() {
                if let Some(masks) = &query_masks {
                    // Pruning with the blume filter.
                    if !child.match_attribute_mask(masks) {
                        return Some(placeids);
                    }
                }

                placeids.extend(child.get_values());
                target_node = &**child;
            } else {
                break;
            }
        }

        if quadkeys.len() < self.key_length as usize {
            self.get_placeids(target_node, &mut placeids, &query_masks);
        }

        Some(placeids)
    }

    fn get_placeids(
        &self,
        node: &QuadNode,
        values: &mut HashSet<place::object::GooglePlaceSearchPlaceId>,
        query_masks: &Option<Vec<[u64; 4]>>,
    ) {
        if let Some(masks) = query_masks {
            if !node.match_attribute_mask(masks) {
                return;
            }
        }

        values.extend(node.get_values());
        for idx in 0..node.child.len() {
            if let Some(next_node) = node.child[idx].as_ref() {
                self.get_placeids(next_node, values, query_masks);
            }
        }
    }
}
