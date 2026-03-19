use std::collections::HashMap;
use std::f32;
use std::hash::{DefaultHasher, Hash, Hasher};

use ordered_float;
use sqlx::prelude;
use strum::{AsRefStr, Display, EnumString};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct SearchMetrics {
    pub is_hit: bool,
    pub upstream_response_time: Option<f64>,
    pub result_count: usize,
}

/// Parsed field mask for validating cache compatibility.
/// Strips "places." prefix used by Text Search API field masks.
#[derive(Debug, Clone)]
pub struct FieldMask {
    fields: Vec<String>,
}

impl FieldMask {
    pub fn from_text_search_mask(mask: &str) -> Self {
        let fields: Vec<String> = mask
            .split(',')
            .map(|s| {
                let trimmed = s.trim();
                trimmed
                    .strip_prefix("places.")
                    .unwrap_or(trimmed)
                    .to_string()
            })
            .filter(|s| !s.is_empty())
            .collect();
        Self { fields }
    }

    pub fn get_fields(&self) -> &[String] {
        &self.fields
    }
}

// Inforation of user client what need to place search.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaceSearchClientParamater {
    pub latitude: f64,
    pub longitude: f64,
    pub window_width: f64,
    pub window_height: f64,
    pub map_zoom_level: usize,
    pub result_offset: usize,
    pub result_limit: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SelectPlaceParams {
    pub latitude: f64,
    pub longitude: f64,
    pub expires_at: chrono::DateTime<chrono::Utc>,
    pub included_types: Vec<String>,
    pub field_mask: String,
    pub radius: f64,
}

// Place Id hash key for trie tree.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct GooglePlaceSearchPlaceId {
    place_id: String,
}

impl GooglePlaceSearchPlaceId {
    pub fn new(place_id: String) -> Self {
        Self { place_id }
    }

    pub fn make_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        self.place_id.hash(&mut hasher);
        hasher.finish()
    }

    pub fn as_str(&self) -> &str {
        &self.place_id
    }
}

// ----------------- Google places search request paramaters. ----------------- //
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GooglePlacesPlaceDetailBodyParamater {
    pub field_mask: String,
    place_ids: Vec<String>,
    language_code: Option<String>,
    region_code: Option<String>,
    session_token: Option<String>,
}

impl GooglePlacesPlaceDetailBodyParamater {
    pub fn get_place_ids(&self) -> Vec<String> {
        self.place_ids.clone()
    }

    pub fn get_field_mask(&self) -> String {
        self.field_mask.clone()
    }

    pub fn get_language_code(&self) -> Option<String> {
        self.language_code.clone()
    }

    pub fn get_region_code(&self) -> Option<String> {
        self.region_code.clone()
    }

    pub fn get_session_token(&self) -> Option<String> {
        self.session_token.clone()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GooglePlacesTextSearchParamater {
    pub field_mask: String,
    request_paramater: GooglePlacesTextSearchRequestParamater,
}

impl GooglePlacesTextSearchParamater {
    pub fn get_field_mask(&self) -> String {
        self.field_mask.clone()
    }

    pub fn get_request_paramater(&self) -> GooglePlacesTextSearchRequestParamater {
        self.request_paramater.clone()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesTextSearchRequestParamater {
    text_query: String,
    included_type: Option<GooglePlaceType>,
    language_code: Option<String>,
    location_bias: Option<GooglePlacesLocationBias>,
    open_now: Option<bool>,
    page_size: Option<i16>,
    price_levels: Option<Vec<GooglePlacesSearchResponsePriceLevel>>,
    rank_preference: Option<String>,
    strict_type_filtering: Option<bool>,
}

impl GooglePlacesTextSearchRequestParamater {
    pub fn get_location_bias(&self) -> Option<&GooglePlacesLocationBias> {
        self.location_bias.as_ref()
    }

    pub fn get_included_type(&self) -> Option<GooglePlaceType> {
        if let Some(place_type) = self.included_type.clone() {
            return Some(place_type);
        }
        None
    }

    /// Build a stripped-down copy for ID-only API calls (FieldMask="places.id", page_size=20).
    pub fn to_id_only_param(&self) -> Self {
        Self {
            text_query: self.text_query.clone(),
            included_type: self.included_type.clone(),
            language_code: self.language_code.clone(),
            location_bias: self.location_bias.clone(),
            open_now: self.open_now,
            page_size: Some(20),
            price_levels: self.price_levels.clone(),
            rank_preference: self.rank_preference.clone(),
            strict_type_filtering: self.strict_type_filtering,
        }
    }

    pub fn get_page_size(&self) -> Option<i16> {
        if let Some(page_size) = self.page_size {
            return Some(page_size);
        }
        None
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GooglePlacesLocationBias {
    circle: Option<Circle>,
}

impl GooglePlacesLocationBias {
    pub fn get_circle(&self) -> Option<&Circle> {
        self.circle.as_ref()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GooglePlacesNearbySearchParamater {
    request_paramater: GooglePlacesNearbySearchBodyParamater,
    pub field_mask: String, // Required parameter
    client_paramater: PlaceSearchClientParamater,
}

impl GooglePlacesNearbySearchParamater {
    pub fn get_client_paramater_ref(&self) -> &PlaceSearchClientParamater {
        &self.client_paramater
    }

    pub fn get_request_paramater(&self) -> GooglePlacesNearbySearchBodyParamater {
        let request_paramater = self.request_paramater.clone();
        request_paramater
    }

    pub fn get_header_field(&self) -> HashMap<String, String> {
        let mut header_field: HashMap<String, String> = HashMap::new();
        header_field.insert(
            "X-Goog-FieldMask".to_string(),
            self.field_mask.as_str().to_string(),
        );
        header_field
    }

    pub fn get_field_mask(&self) -> String {
        let field_mask: &str = self.field_mask.as_ref();
        field_mask.to_string()
    }

    pub fn new(
        request_paramater: GooglePlacesNearbySearchBodyParamater,
        field_mask: String,
        client_paramater: PlaceSearchClientParamater,
    ) -> Self {
        Self {
            request_paramater,
            field_mask,
            client_paramater,
        }
    }

    pub fn to_tile_param(&self, lat: f64, lon: f64, radius: f64) -> Self {
        Self {
            request_paramater: self
                .request_paramater
                .to_tile_search_param(lat, lon, radius),
            field_mask: self.field_mask.clone(),
            client_paramater: self.client_paramater.clone(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesNearbySearchBodyParamater {
    #[serde(skip_serializing_if = "Option::is_none")]
    included_types: Option<Vec<String>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    excluded_types: Option<Vec<String>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    included_primary_types: Option<Vec<String>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    excluded_primary_types: Option<Vec<String>>,

    #[serde(skip_serializing_if = "Option::is_none")]
    max_result_count: Option<usize>,

    #[serde(skip_serializing_if = "Option::is_none")]
    language_code: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    rank_preference: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    region_code: Option<String>,

    location_restriction: LocationRestriction, // Required parameter
}

impl GooglePlacesNearbySearchBodyParamater {
    pub fn new(
        included_types: Option<Vec<String>>,
        max_result_count: Option<usize>,
        rank_preference: Option<String>,
        lat: f64,
        lon: f64,
        radius: f64,
    ) -> Self {
        Self {
            included_types,
            excluded_types: None,
            included_primary_types: None,
            excluded_primary_types: None,
            max_result_count,
            language_code: Some("ja".to_string()),
            rank_preference,
            region_code: Some("JP".to_string()),
            location_restriction: LocationRestriction {
                circle: Circle {
                    center: Center {
                        latitude: lat,
                        longitude: lon,
                    },
                    radius,
                },
            },
        }
    }

    pub fn get_types(&self) -> Vec<GooglePlaceType> {
        let mut tree_types: Vec<GooglePlaceType> = Vec::new();

        if let Some(included_types) = self.included_types.as_ref() {
            for t in included_types.into_iter() {
                let v = serde_json::Value::String(t.to_string());
                let place_type: GooglePlaceType = serde_json::from_value(v).ok().unwrap();
                tree_types.push(place_type);
            }
        }

        tree_types
    }

    pub fn get_restriction(&self) -> LocationRestriction {
        self.location_restriction.clone()
    }

    pub fn to_tile_search_param(&self, lat: f64, lon: f64, radius: f64) -> Self {
        Self {
            included_types: self.included_types.clone(),
            excluded_types: self.excluded_types.clone(),
            included_primary_types: self.included_primary_types.clone(),
            excluded_primary_types: self.excluded_primary_types.clone(),
            max_result_count: Some(20),
            language_code: self.language_code.clone(),
            rank_preference: self.rank_preference.clone(),
            region_code: self.region_code.clone(),
            location_restriction: LocationRestriction {
                circle: Circle {
                    center: Center {
                        latitude: lat,
                        longitude: lon,
                    },
                    radius,
                },
            },
        }
    }

    pub fn get_max_result_count(&self) -> Option<usize> {
        self.max_result_count
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocationRestriction {
    circle: Circle,
}

impl LocationRestriction {
    pub fn get_circle(&self) -> Circle {
        self.circle.clone()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Circle {
    center: Center,
    pub radius: f64,
}

impl Circle {
    pub fn get_center(&self) -> Center {
        self.center.clone()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Center {
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(
    Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash, AsRefStr, EnumString, Display,
)]
#[serde(rename_all = "snake_case")]
pub enum GooglePlaceType {
    // Automotive
    CarDealer,
    CarRental,
    CarRepair,
    CarWash,
    ElectricVehicleChargingStation,
    Station,
    GasStation,
    Parking,
    RestStop,

    // Business
    CorporateOffice,
    Farm,
    Ranch,

    // Culture
    ArtGallery,
    ArtStudio,
    Auditorium,
    CulturalLandmark,
    HistoricalPlace,
    Monument,
    Museum,
    PerformingArtsTheater,
    Sculpture,

    // Education
    Library,
    Preschool,
    PrimarySchool,
    School,
    SecondarySchool,
    University,

    // Entertainment and Recreation
    AdventureSportsCenter,
    Amphitheatre,
    AmusementCenter,
    AmusementPark,
    Aquarium,
    BanquetHall,
    BarbecueArea,
    BotanicalGarden,
    BowlingAlley,
    Casino,
    ChildrensCamp,
    ComedyClub,
    CommunityCenter,
    ConcertHall,
    ConventionCenter,
    CulturalCenter,
    CyclingPark,
    DanceHall,
    DogPark,
    EventVenue,
    FerrisWheel,
    Garden,
    HikingArea,
    HistoricalLandmark,
    InternetCafe,
    Karaoke,
    Marina,
    MovieRental,
    MovieTheater,
    NationalPark,
    NightClub,
    ObservationDeck,
    OffRoadingArea,
    OperaHouse,
    Park,
    PhilharmonicHall,
    PicnicGround,
    Planetarium,
    Plaza,
    RollerCoaster,
    SkateboardPark,
    StatePark,
    TouristAttraction,
    VideoArcade,
    VisitorCenter,
    WaterPark,
    WeddingVenue,
    WildlifePark,
    WildlifeRefuge,
    Zoo,

    // Facilities
    PublicBath,
    PublicBathroom,
    Stable,

    // Finance
    Accounting,
    Atm,
    Bank,

    // Food and Drink
    AcaiShop,
    AfghaniRestaurant,
    AfricanRestaurant,
    AmericanRestaurant,
    AsianRestaurant,
    BagelShop,
    Bakery,
    Bar,
    BarAndGrill,
    BarbecueRestaurant,
    BrazilianRestaurant,
    BreakfastRestaurant,
    BrunchRestaurant,
    BuffetRestaurant,
    Cafe,
    Cafeteria,
    CandyStore,
    CatCafe,
    ChineseRestaurant,
    ChocolateFactory,
    ChocolateShop,
    CoffeeShop,
    Confectionery,
    Deli,
    DessertRestaurant,
    DessertShop,
    Diner,
    DogCafe,
    DonutShop,
    FastFoodRestaurant,
    FineDiningRestaurant,
    FoodCourt,
    Food,
    FrenchRestaurant,
    GreekRestaurant,
    HamburgerRestaurant,
    IceCreamShop,
    IndianRestaurant,
    IndonesianRestaurant,
    ItalianRestaurant,
    JapaneseRestaurant,
    JuiceShop,
    KoreanRestaurant,
    LebaneseRestaurant,
    MealDelivery,
    MealTakeaway,
    MediterraneanRestaurant,
    MexicanRestaurant,
    MiddleEasternRestaurant,
    PizzaRestaurant,
    Pub,
    RamenRestaurant,
    Restaurant,
    SandwichShop,
    SeafoodRestaurant,
    SpanishRestaurant,
    SteakHouse,
    SushiRestaurant,
    TeaHouse,
    ThaiRestaurant,
    TurkishRestaurant,
    VeganRestaurant,
    VietnameseRestaurant,
    WineBar,

    // Geographical Area
    AdministrativeAreaLevel1,
    AdministrativeAreaLevel2,
    Country,
    Locality,
    PostalCode,
    SchoolDistrict,

    // Government
    CityHall,
    Courthouse,
    Embassy,
    FireStation,
    GovernmentOffice,
    LocalGovernmentOffice,
    NeighborhoodPoliceStation,
    Police,
    PostOffice,

    // Health and Wellness
    Chiropractor,
    DentalClinic,
    Dentist,
    Doctor,
    Drugstore,
    Hospital,
    Massage,
    MedicalLab,
    Pharmacy,
    Physiotherapist,
    Sauna,
    SkinCareClinic,
    Spa,
    TanningStudio,
    WellnessCenter,
    YogaStudio,

    // Housing
    ApartmentBuilding,
    ApartmentComplex,
    CondominiumComplex,
    HousingComplex,

    // Lodging
    BedAndBreakfast,
    BudgetJapaneseInn,
    Campground,
    CampingCabin,
    Cottage,
    ExtendedStayHotel,
    Farmstay,
    GuestHouse,
    Hostel,
    Hotel,
    Inn,
    JapaneseInn,
    Lodging,
    MobileHomePark,
    Motel,
    PrivateGuestRoom,
    ResortHotel,
    RvPark,

    // Natural Features
    Beach,

    // Places of Worship
    Church,
    HinduTemple,
    Mosque,
    Synagogue,

    // Services
    Astrologer,
    BarberShop,
    Beautician,
    BeautySalon,
    BodyArtService,
    CateringService,
    Cemetery,
    ChildCareAgency,
    Consultant,
    CourierService,
    Electrician,
    Florist,
    FoodDelivery,
    FootCare,
    FuneralHome,
    HairCare,
    InsuranceAgency,
    Laundry,
    Lawyer,
    Locksmith,
    MarkupArtist,
    MovingCompany,
    NailSalon,
    Painter,
    Plumber,
    Psychic,
    RealEstateAgency,
    RoofingContractor,
    Storage,
    SummerCampOrganizer,
    Tailor,
    TelecommunicationsServiceProvider,
    TourAgency,
    TouristInformationCenter,
    TravelAgency,
    VeterinaryCafe,

    // Shopping
    AsianGroceryStore,
    AutoPartsStore,
    BicycleStore,
    BookStore,
    ButcherShop,
    CellPhoneStore,
    ClothingStore,
    ConvenienceStore,
    DepartmentStore,
    DiscountStore,
    ElectronicsStore,
    FoodStore,
    FurnitureStore,
    GiftShop,
    GroceryStore,
    HardwareStore,
    HomeGoodsStore,
    HomeImprovementStore,
    JewelryStore,
    LiquorStore,
    Market,
    PetStore,
    ShopStore,
    ShoppingMall,
    SportingGoodsStore,
    Store,
    Supermarket,
    WarehouseStore,
    Wholesaler,

    // Sports
    Arena,
    AthleticField,
    FishingCharter,
    FishingPond,
    FitnessCenter,
    GolfCourse,
    Gym,
    IceSkatingRink,
    Playground,
    SkiResort,
    SportsActivityLocation,
    SportsClub,
    SportsCoaching,
    SportsComplex,
    Stadium,
    SwimmingPool,

    // Transportation
    Airport,
    Airstrip,
    BusStation,
    FerryTerminal,
    Heliport,
    InternationalAirport,
    LightRailStation,
    ParkAndRide,
    SubwayStation,
    TaxiStand,
    TrainStation,
    TransitDepot,
    TransitStation,
    TruckStop,
}

// ----------------- Google places search response paramater ----------------- //
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponse {
    places: Option<Vec<GooglePlacesSearchResponsePlace>>,
    routing_summaries: Option<Vec<GooglePlacesSearchResponseRoutingSummary>>,
}

impl GooglePlacesSearchResponse {
    pub fn get_places(&self) -> Option<Vec<GooglePlacesSearchResponsePlace>> {
        if let Some(places_ref) = self.places.as_ref() {
            let places: Vec<GooglePlacesSearchResponsePlace> = places_ref
                .into_iter()
                .map(|p| {
                    let mut cloned_p = p.clone();
                    cloned_p.reduce_photos();
                    cloned_p
                })
                .collect();

            return Some(places.clone());
        }
        None
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesTextSearchResponse {
    pub places: Option<Vec<GooglePlacesSearchResponsePlace>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePlace {
    name: Option<String>,
    id: Option<String>,
    display_name: Option<GooglePlacesSearchResponseLocalizedText>,
    types: Option<Vec<String>>,
    primary_type: Option<String>,
    primary_type_display_name: Option<GooglePlacesSearchResponseLocalizedText>,
    national_phone_number: Option<String>,
    formatted_address: Option<String>,
    short_formatted_address: Option<String>,
    postal_address: Option<GooglePlacesSearchResponsePostalAddress>,
    address_components: Option<Vec<GooglePlacesSearchResponseAddressComponent>>,
    plus_code: Option<GooglePlacesSearchResponsePlusCode>,
    location: Option<GooglePlacesSearchResponseLatLng>,
    viewport: Option<GooglePlacesSearchResponseViewPort>,
    rating: Option<ordered_float::OrderedFloat<f32>>,
    google_maps_url: Option<String>,
    website_uri: Option<String>,
    reviews: Option<Vec<GooglePlacesSearchResponseReview>>,
    regular_opening_hours: Option<GooglePlacesSearchResponseOpeningHour>,
    time_zone: Option<GooglePlacesSearchResponseTimeZone>,
    photos: Option<Vec<GooglePlacesSearchResponsePhoto>>,
    adr_format_address: Option<String>,
    business_status: Option<GooglePlacesSearchResponseBusinessStatus>,
    price_level: Option<GooglePlacesSearchResponsePriceLevel>,
    attributions: Option<Vec<GooglePlacesSearchResponseAttribution>>,
    icon_mask_base_uri: Option<String>,
    icon_background_color: Option<String>,
    current_opening_hours: Option<GooglePlacesSearchResponseOpeningHour>,
    current_secondary_opening_hours: Option<Vec<GooglePlacesSearchResponseOpeningHour>>,
    regular_secondary_opening_hours: Option<Vec<GooglePlacesSearchResponseOpeningHour>>,
    editorial_summary: Option<GooglePlacesSearchResponseLocalizedText>,
    payment_options: Option<GooglePlacesSearchResponsePaymentOptions>,
    parking_options: Option<GooglePlacesSearchResponseParkingOptions>,
    sub_destinations: Option<Vec<GooglePlacesSearchResponseSubDestination>>,
    fuel_options: Option<GooglePlacesSearchResponseFuelOptions>,
    ev_charge_options: Option<GooglePlacesSearchResponseEVChargeOptions>,
    generative_summary: Option<GooglePlacesSearchResponseGenerativeSummary>,
    containing_places: Option<GooglePlacesSearchResponseContainingPlaces>,
    address_descriptor: Option<GooglePlacesSearchResponseAddressDescriptor>,
    google_maps_links: Option<GooglePlacesSearchResponseGoogleMapsLinks>,
    price_range: Option<GooglePlacesSearchResponsePriceRange>,
    review_summary: Option<GooglePlacesSearchResponseReviewSummary>,
    ev_charge_amenity_summary: Option<GooglePlacesSearchResponseEvChargeAmenitySummary>,
    neighborhood_summary: Option<GooglePlacesSearchResponseNeighborhoodSummary>,
    consumer_alert: Option<GooglePlacesSearchResponseConsumerAlert>,
    moved_place: Option<String>,
    moved_place_id: Option<String>,
    utc_offset_minutes: Option<i32>,
    user_rating_count: Option<u64>,
    takeout: Option<bool>,
    delivery: Option<bool>,
    dine_in: Option<bool>,
    curbside_pickup: Option<bool>,
    reservable: Option<bool>,
    serves_breakfast: Option<bool>,
    serves_lunch: Option<bool>,
    serves_dinner: Option<bool>,
    serves_beer: Option<bool>,
    serves_wine: Option<bool>,
    serves_brunch: Option<bool>,
    serves_vegetarian_food: Option<bool>,
    outdoor_seating: Option<bool>,
    live_music: Option<bool>,
    menu_for_children: Option<bool>,
    serves_cocktails: Option<bool>,
    serves_dessert: Option<bool>,
    serves_coffee: Option<bool>,
    good_for_children: Option<bool>,
    allows_dogs: Option<bool>,
    restroom: Option<bool>,
    good_for_groups: Option<bool>,
    good_for_watching_sports: Option<bool>,
    accessibility_options: Option<GooglePlacesSearchResponseAccessibilityOptions>,
    pure_service_area_business: Option<bool>,
}

impl GooglePlacesSearchResponsePlace {
    pub fn get_place_id(&self) -> Option<String> {
        if let Some(place_id) = self.id.as_ref() {
            return Some(place_id.clone());
        }
        None
    }

    pub fn get_rating(&self) -> Option<ordered_float::OrderedFloat<f32>> {
        self.rating
    }

    pub fn get_latlng(&self) -> Option<GooglePlacesSearchResponseLatLng> {
        if let Some(location) = self.location.as_ref() {
            return Some(location.clone());
        }
        None
    }

    pub fn get_types(&self) -> Option<Vec<GooglePlaceType>> {
        if let Some(types) = self.types.as_ref() {
            let mut places: Vec<GooglePlaceType> = Vec::new();
            for t in types.into_iter() {
                let v = serde_json::Value::String(t.to_string());
                let place_type: Option<GooglePlaceType> = serde_json::from_value(v).ok();
                if let Some(place_type) = place_type {
                    places.push(place_type);
                }
            }

            return Some(places);
        }
        None
    }

    pub fn reduce_photos(&mut self) {
        if let Some(photos) = self.photos.as_ref() {
            let limit_photos: Vec<GooglePlacesSearchResponsePhoto> = photos
                .into_iter()
                .filter_map(|p| Some(p.clone()))
                .take(5)
                .collect();

            self.photos = Some(limit_photos);
        }
    }

    /// Return raw type strings without parsing to GooglePlaceType enum.
    pub fn get_raw_types(&self) -> Option<&Vec<String>> {
        self.types.as_ref()
    }

    /// Check whether this cached place satisfies all fields in the given mask.
    pub fn is_cache_compatible(&self, mask: &FieldMask) -> bool {
        let value = match serde_json::to_value(self) {
            Ok(v) => v,
            Err(_) => return false,
        };
        let obj = match value.as_object() {
            Some(o) => o,
            None => return false,
        };
        for field in mask.get_fields() {
            match obj.get(field) {
                Some(v) if !v.is_null() => continue,
                _ => return false,
            }
        }
        true
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseRoutingSummary {
    legs: Option<Vec<GooglePlacesSearchResponseLeg>>,
    directions_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseLeg {
    duration: Option<String>,
    distance_meters: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseLocalizedText {
    text: Option<String>,
    language_code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePostalAddress {
    revision: Option<String>,
    region_code: Option<String>,
    language_code: Option<String>,
    postal_code: Option<String>,
    sorting_code: Option<String>,
    administrative_area: Option<String>,
    locality: Option<String>,
    sub_locality: Option<String>,
    address_liens: Option<Vec<String>>,
    recipients: Option<Vec<String>>,
    organization: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseAddressComponent {
    long_text: Option<String>,
    short_text: Option<String>,
    types: Option<Vec<String>>,
    language_code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePlusCode {
    global_code: Option<String>,
    compound_code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseLatLng {
    latitude: Option<ordered_float::OrderedFloat<f64>>,
    longitude: Option<ordered_float::OrderedFloat<f64>>,
}

impl GooglePlacesSearchResponseLatLng {
    pub fn get_lat(&self) -> Option<f64> {
        if let Some(latitude) = self.latitude.as_ref() {
            let lat = latitude.into_inner();
            return Some(lat);
        }
        None
    }

    pub fn get_lon(&self) -> Option<f64> {
        if let Some(longitude) = self.longitude.as_ref() {
            let lon = longitude.into_inner();
            return Some(lon);
        }
        None
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseViewPort {
    low: Option<GooglePlacesSearchResponseLatLng>,
    high: Option<GooglePlacesSearchResponseLatLng>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseReview {
    name: Option<String>,
    relative_publish_time_description: Option<String>,
    text: Option<GooglePlacesSearchResponseLocalizedText>,
    original_text: Option<GooglePlacesSearchResponseLocalizedText>,
    rating: Option<ordered_float::OrderedFloat<f32>>,
    author_attribution: Option<GooglePlacesSearchResponseAuthorAttribution>,
    publish_time: Option<String>,
    flag_content_uri: Option<String>,
    google_maps_uri: Option<String>,
    visit_date: Option<GooglePlacesSearchResponseDate>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseAuthorAttribution {
    display_name: Option<String>,
    uri: Option<String>,
    photo_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseDate {
    year: Option<u16>,
    month: Option<u16>,
    day: Option<u16>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseOpeningHour {
    periods: Option<Vec<GooglePlacesSearchResponsePeriod>>,
    weekday_descriptions: Option<Vec<String>>,
    secondary_hours_type: Option<GooglePlaceseSearchResponseSecondaryHoursType>,
    special_days: Option<Vec<GooglePlacesSearchResponseSpecialDay>>,
    next_open_time: Option<String>,
    next_close_time: Option<String>,
    open_now: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponsePeriod {
    open: Option<GooglePlacesSearchResponsePoint>,
    close: Option<GooglePlacesSearchResponsePoint>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponsePoint {
    date: Option<GooglePlacesSearchResponseDate>,
    truncated: Option<bool>,
    day: Option<u16>,
    hour: Option<u8>,
    minute: Option<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlaceseSearchResponseSecondaryHoursType {
    SecondaryHoursTypeUnspecified,
    DriveThrough,
    HappyHour,
    Delivery,
    Takeout,
    Kitchen,
    Breakfast,
    Lunch,
    Dinner,
    Brunch,
    Pickup,
    Access,
    SeniorHours,
    OnlineServiceHours,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseSpecialDay {
    date: Option<GooglePlacesSearchResponseDate>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseTimeZone {
    id: Option<String>,
    version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePhoto {
    name: Option<String>,
    width_px: Option<u32>,
    height_px: Option<u32>,
    author_attributions: Option<Vec<GooglePlacesSearchResponseAuthorAttribution>>,
    flag_content_uri: Option<String>,
    google_maps_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponseBusinessStatus {
    BusinessStatusUnspecified,
    Operational,
    ClosedTemporarily,
    ClosedPermanently,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponsePriceLevel {
    PriceLevelUnspecified,
    PriceLevelFree,
    PriceLevelInexpensive,
    PriceLevelModerate,
    PriceLevelExpensive,
    PriceLevelVeryExpensive,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseAttribution {
    provider: Option<String>,
    provider_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePaymentOptions {
    accepts_credit_cards: Option<bool>,
    accepts_debit_cards: Option<bool>,
    accepts_cash_only: Option<bool>,
    accepts_nfc: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseParkingOptions {
    free_parking_lot: Option<bool>,
    paid_parking_lot: Option<bool>,
    free_street_parking: Option<bool>,
    paid_street_parking: Option<bool>,
    valet_parking: Option<bool>,
    free_garage_parking: Option<bool>,
    paid_garage_parking: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseSubDestination {
    name: Option<String>,
    id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseFuelOptions {
    fuel_prices: Option<Vec<GooglePlacesSearchResponseFuelPrice>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseFuelPrice {
    r#type: Option<GooglePlacesSearchResponseFuelType>,
    price: Option<GooglePlacesSearchResponseMoney>,
    update_time: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponseFuelType {
    FuelTypeUnspecified,
    Diesel,
    DieselPlus,
    RegularUnleaded,
    Midgrade,
    Premium,
    Sp91,
    Sp91E10,
    Sp92,
    Sp95,
    Sp95E10,
    Sp98,
    Sp99,
    Sp100,
    Lpg,
    E80,
    E85,
    E100,
    Methane,
    BioDiesel,
    TruckDiesel,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseMoney {
    currency_code: Option<String>,
    units: Option<String>,
    nanos: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseEVChargeOptions {
    connector_count: Option<u64>,
    connector_aggregation: Option<Vec<GooglePlacesSearchResponseConnectorAggregation>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseConnectorAggregation {
    r#type: Option<GooglePlacesSearchResponseEVConnectorType>,
    max_charge_rate_kw: Option<ordered_float::OrderedFloat<f64>>,
    count: Option<u64>,
    availability_last_update_time: Option<String>,
    available_count: Option<u64>,
    out_of_service_count: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponseEVConnectorType {
    EvConnectorTypeUnspecified,
    EvConnectorTypeOther,
    EvConnectorTypeJ1771,
    EvConnectorTypeType2,
    EvConnectorTypeChademo,
    EvConnectorTypeCcsCombo1,
    EvConnectorTypeCcsCombo2,
    EvConnectorTypeTesla,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub struct GooglePlacesSearchResponseGenerativeSummary {
    overview: Option<GooglePlacesSearchResponseLocalizedText>,
    overview_flag_content_uri: Option<String>,
    disclosure_text: Option<GooglePlacesSearchResponseLocalizedText>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseContainingPlaces {
    name: Option<String>,
    id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseAddressDescriptor {
    landmarks: Option<Vec<GooglePlacesSearchResponseLandmark>>,
    areas: Option<Vec<GooglePlacesSearchResponseArea>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseLandmark {
    name: Option<String>,
    place_id: Option<String>,
    display_name: Option<GooglePlacesSearchResponseLocalizedText>,
    types: Option<Vec<String>>,
    spatial_relationship: Option<GooglePlacesSearchResponseSpatialRelationship>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponseSpatialRelationship {
    Near,
    Within,
    Beside,
    AcrossTheRoad,
    DownTheRoad,
    AroundTheCorner,
    Behind,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseArea {
    name: Option<String>,
    place_id: Option<String>,
    display_name: Option<GooglePlacesSearchResponseLocalizedText>,
    containment: Option<GooglePlacesSearchResponseContainment>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum GooglePlacesSearchResponseContainment {
    ContainmentUnspecified,
    Within,
    Outskirts,
    Near,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseGoogleMapsLinks {
    direction_uri: Option<String>,
    place_uri: Option<String>,
    write_a_review_uri: Option<String>,
    reviews_uri: Option<String>,
    photo_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponsePriceRange {
    start_price: Option<GooglePlacesSearchResponseMoney>,
    end_price: Option<GooglePlacesSearchResponseMoney>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseReviewSummary {
    text: Option<GooglePlacesSearchResponseLocalizedText>,
    flag_content_uri: Option<String>,
    disclosure_text: Option<GooglePlacesSearchResponseLocalizedText>,
    reviews_uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseEvChargeAmenitySummary {
    overview: Option<GooglePlacesSearchResponseContentBlock>,
    coffee: Option<GooglePlacesSearchResponseContentBlock>,
    restaurant: Option<GooglePlacesSearchResponseContentBlock>,
    store: Option<GooglePlacesSearchResponseContentBlock>,
    flag_content_uri: Option<String>,
    disclosure_text: Option<GooglePlacesSearchResponseLocalizedText>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseContentBlock {
    content: Option<GooglePlacesSearchResponseLocalizedText>,
    referenced_places: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseNeighborhoodSummary {
    overview: Option<GooglePlacesSearchResponseContentBlock>,
    description: Option<GooglePlacesSearchResponseContentBlock>,
    flag_content_uri: Option<String>,
    disclosure_text: Option<GooglePlacesSearchResponseLocalizedText>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseConsumerAlert {
    overview: Option<String>,
    details: Option<GooglePlacesSearchResponseDetails>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseDetails {
    title: Option<String>,
    description: Option<String>,
    about_link: Option<GooglePlacesSearchResponseLink>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct GooglePlacesSearchResponseLink {
    title: Option<String>,
    uri: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub struct GooglePlacesSearchResponseAccessibilityOptions {
    wheelchair_accessible_parking: Option<bool>,
    wheelchair_accessible_entrance: Option<bool>,
    wheelchair_accessible_restroom: Option<bool>,
    wheelchair_accessible_seating: Option<bool>,
}

// Google places object for postgres

#[derive(Debug, Clone, prelude::FromRow)]
pub struct GooglePlacesPhotoReference {
    pub id: i64,
    pub place_id: String,
    pub reference: String,
    pub max_width_px: i32,
    pub max_height_px: i32,
    pub expires_at: i64,
    pub created_at: i64,
}

impl GooglePlacesPhotoReference {
    pub fn new(
        place_id: String,
        reference: String,
        media: PhotoQuery,
        expires_in: chrono::Duration,
    ) -> Self {
        let mut hasher = DefaultHasher::new();
        let combined = format!(
            "{}/{}/{}&{}",
            place_id, reference, media.max_height_px, media.max_width_px
        );
        combined.hash(&mut hasher);

        let id = hasher.finish() as i64;
        let expires_at = chrono::Utc::now() + expires_in;
        let created_at = chrono::Utc::now();

        Self {
            id,
            place_id,
            reference,
            max_height_px: media.max_height_px,
            max_width_px: media.max_width_px,
            expires_at: expires_at.timestamp(),
            created_at: created_at.timestamp(),
        }
    }

    pub fn make_url(&self) -> String {
        let mut endpoint = std::env::var("GOOGLE_API_PLACES_PHOTO_ENDPOINT").unwrap();
        let api_key = std::env::var("GMS_API_KEY").unwrap();
        endpoint = format!(
            "{}/places/{}/photos/{}/media?key={}&maxHeightPx={}&maxWidthPx={}",
            endpoint, self.place_id, self.reference, api_key, self.max_height_px, self.max_width_px
        );

        endpoint
    }

    pub fn make_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        let combined_str = format!(
            "{}/{}/{}&{}",
            self.place_id, self.reference, self.max_height_px, self.max_width_px,
        );
        combined_str.hash(&mut hasher);
        hasher.finish()
    }
}

#[derive(Debug, Clone, Deserialize, prelude::FromRow)]
pub struct PhotoQuery {
    #[serde(rename = "maxWidthPx")]
    pub max_width_px: i32,
    #[serde(rename = "maxHeightPx")]
    pub max_height_px: i32,
}
