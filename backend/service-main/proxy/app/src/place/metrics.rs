use std::f64;

use ahash;

use crate::place;

pub fn compute_quadkeys(lon: f64, lat: f64, zoom: usize) -> String {
    // This method for computing the quadkey from world coordinates. The number of
    // zoom levels corresponds to the length of the quadkey. The specific computing method
    // was referenced from the following site.
    // https://learn.microsoft.com/en-us/bingmaps/articles/bing-maps-tile-system?redirectedfrom=MSDN

    let (x, y) = compute_pixel_coordinate(lon, lat, zoom);
    let tile_x = (x / 256.0).floor() as u64;
    let tile_y = (y / 256.0).floor() as u64;

    let mut quadkey = String::with_capacity(zoom);

    for z in (0..zoom).rev() {
        let mask = 1 << z;
        let bit_x = 1 & ((tile_x & mask) >> z) as u32;
        let bit_y = 2 * (1 & ((tile_y & mask) >> z)) as u32;
        let c = std::char::from_digit(bit_x + bit_y, 10).unwrap();
        quadkey.push(c);
    }

    quadkey
}

pub fn compute_coordinate(x: f64, y: f64, zoom: usize) -> (f64, f64) {
    // This function to compute longitude and latitude from world coordinate values based on the
    // mathmetical formula represented by the Mercator projection.
    // The x and y values received as arguments are pixel values in the wold coordinate system,
    // scaled by a factor of zoom.

    // Compute grid size.
    let grid_size = 256.0 * 2_f64.powi(zoom as i32);

    // Normalize pixel coordinates.
    let nx = x / grid_size;
    let ny = y / grid_size;

    // Compute longitude
    let lon = 360.0 * (nx - 0.5);

    // Compute latitude.
    let lat_rad = 2.0 * (f64::consts::PI * (1.0 - 2.0 * ny)).exp().atan() - (f64::consts::PI / 2.0);
    let mut lat = lat_rad.to_degrees();
    lat = f64::min(85.051129, f64::max(-85.051129, lat));

    (lon, lat)
}

pub fn compute_pixel_coordinate(lon: f64, lat: f64, zoom: usize) -> (f64, f64) {
    // Method for computing world coordinates from longitude and latitude.
    // The formula were referenced below site.
    // https://en.wikipedia.org/wiki/Web_Mercator_projection

    let x = (lon + 180.0) / 360.0;
    let sin_lat = (lat * std::f64::consts::PI / 180.0).sin();
    let y = 0.5 - ((1.0 + sin_lat) / (1.0 - sin_lat)).ln() / (4.0 * std::f64::consts::PI);

    // Compute map size
    let map_size = 256.0 * 2_f64.powf(zoom as f64);

    // Adjust pixel coordinate to map size.
    let scaled_x = x * map_size;
    let scaled_y = y * map_size;

    (scaled_x, scaled_y)
}

pub fn compute_zoom_level(radius: f64, latitude: f64) -> f64 {
    // Earch equational radius from WGS84.
    let r = 6378137.0;

    // Target grid length.
    let target_length = 2.0 * radius;
    let theta = latitude.to_radians();

    // Initial length.
    let grid_length = 2.0 * f64::consts::PI * r * theta.cos();

    // Compute taget zoom level.
    let zoom = (grid_length / target_length).log2();

    zoom
}

pub fn compute_tile_side_length(latitude: f64, zoom: usize) -> f64 {
    const EQUATOR_CIRCUMFERENCE: f64 = 40_075_016.686;
    let lat_rad = latitude * f64::consts::PI / 180.0;
    let num_tiles = 2.0_f64.powi(zoom as i32);

    (EQUATOR_CIRCUMFERENCE * lat_rad.cos()) / num_tiles
}

pub fn compute_ground_resolution(latitude: f64, zoom: f64) -> f64 {
    let r = 6378137.0;
    let theta = latitude.to_radians();
    let gr = 2.0 * f64::consts::PI * r * theta.cos() / (256.0 * f64::powf(2.0, zoom));

    gr
}

pub fn compute_spiral_offset(index: usize) -> (i64, i64) {
    // Maps a linear index to (dx, dy) in a counter-clockwise spiral:
    // Right → Up → Left → Down
    // Leg lengths: 1, 1, 2, 2, 3, 3, ...
    // Index 0→(0,0), 1→(1,0), 2→(1,1), 3→(0,1), 4→(-1,1), 5→(-1,0), 6→(-1,-1), ...

    if index == 0 {
        return (0, 0);
    }

    let mut x: i64 = 0;
    let mut y: i64 = 0;
    // Directions: Right(1,0), Up(0,1), Left(-1,0), Down(0,-1)
    let directions: [(i64, i64); 4] = [(1, 0), (0, 1), (-1, 0), (0, -1)];
    let mut dir_index = 0;
    let mut leg_length = 1;
    let mut steps_in_leg = 0;
    let mut legs_completed = 0;

    for _ in 1..=index {
        let (dx, dy) = directions[dir_index];
        x += dx;
        y += dy;
        steps_in_leg += 1;

        if steps_in_leg == leg_length {
            steps_in_leg = 0;
            dir_index = (dir_index + 1) % 4;
            legs_completed += 1;

            // Increment leg length after every 2 direction changes
            if legs_completed % 2 == 0 {
                leg_length += 1;
            }
        }
    }

    (x, y)
}

pub fn snap_to_tile_center(longitude: f64, latitude: f64, zoom: usize) -> (f64, f64) {
    // Snaps coordinates to the center of their tile at the given zoom level.

    let (px, py) = compute_pixel_coordinate(longitude, latitude, zoom);
    let tile_x = (px / 256.0).floor();
    let tile_y = (py / 256.0).floor();

    let center_px = tile_x * 256.0 + 128.0;
    let center_py = tile_y * 256.0 + 128.0;

    compute_coordinate(center_px, center_py, zoom)
}

pub fn compute_spiral_tile_center(
    base_lon: f64,
    base_lat: f64,
    dx: i64,
    dy: i64,
    tile_side_length: f64,
) -> (f64, f64) {
    // Shifts from snapped base to target tile center using metric offsets.
    const R: f64 = 6_378_137.0;

    let lat_rad = base_lat * f64::consts::PI / 180.0;
    let delta_lat = (dy as f64 * tile_side_length) / R;
    let delta_lon = (dx as f64 * tile_side_length) / (R * lat_rad.cos());

    let new_lat = base_lat + delta_lat.to_degrees();
    let new_lon = base_lon + delta_lon.to_degrees();

    // Clamp latitude
    let clamped_lat = f64::min(85.051129, f64::max(-85.051129, new_lat));

    // Normalize longitude to [-180, 180]
    let mut normalized_lon = new_lon;
    while normalized_lon > 180.0 {
        normalized_lon -= 360.0;
    }
    while normalized_lon < -180.0 {
        normalized_lon += 360.0;
    }

    (normalized_lon, clamped_lat)
}

pub fn compute_blume_hash(
    place: &place::object::GooglePlaceType,
    k: usize,
    m: usize,
) -> Vec<usize> {
    let random_state = ahash::RandomState::with_seeds(42, 42, 42, 42);
    let h1 = random_state.hash_one(place.as_ref());
    let h2 = random_state.hash_one(format!("{}_salt", place.as_ref()));

    (0..k)
        .map(|i| {
            // (h1 + i * h2) (mod m)
            let pos = h1.wrapping_add((i as u64).wrapping_mul(h2)) % m as u64;
            pos as usize
        })
        .collect()
}
