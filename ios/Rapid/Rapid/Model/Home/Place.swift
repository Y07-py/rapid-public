//
//  Place.swift
//  Rapid
//
//  Created by 木本瑛介 on 2025/12/14.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: Text search paramater
public struct GooglePlacesTextSearchParamater: Codable {
    var fieldMask: String
    var requestParamater: GooglePlacesTextSearchRequestParamater
    
    enum CodingKeys: String, CodingKey {
        case fieldMask = "field_mask"
        case requestParamater = "request_paramater"
    }
}

public struct GooglePlacesTextSearchRequestParamater: Codable {
    var textQuery: String
    var includedType: GooglePlaceType?
    var languageCode: String?
    var locationBias: GooglePlacesLocationBias?
    var openNow: Bool?
    var pageSize: Int?
    var priceLevels: [GooglePlacesSearchResponsePriceLevel]?
    var rankPreference: String?
    var strictTypeFiltering: Bool?
    
    public init(
        textQuery: String,
        includedType: GooglePlaceType? = nil,
        languageCode: String? = nil,
        locationBias: GooglePlacesLocationBias? = nil,
        openNow: Bool? = nil,
        pageSize: Int? = nil,
        priceLevels: [GooglePlacesSearchResponsePriceLevel]? = nil,
        rankPreference: String? = nil,
        strictTypeFiltering: Bool? = nil
    ) {
        self.textQuery = textQuery
        self.includedType = includedType
        self.languageCode = languageCode
        self.locationBias = locationBias
        self.openNow = openNow
        self.pageSize = pageSize
        self.priceLevels = priceLevels
        self.rankPreference = rankPreference
        self.strictTypeFiltering = strictTypeFiltering
    }
}

public struct GooglePlacesLocationBias: Codable {
    var circle: LocationCircle
}


// MARK: - Nearest transpor
public struct GooglePlacesTransport: Identifiable, Codable, Equatable {
    public var id: UUID = .init()
    public var l2Distance: Double
    public var place: GooglePlacesSearchResponsePlace
    
    public static func == (lhs: GooglePlacesTransport, rhs: GooglePlacesTransport) -> Bool {
        return lhs.place.id == rhs.place.id
    }
}

// MARK: - Place Search View Structure
public struct GooglePlacesSearchPlaceWrapper: Codable, Identifiable, Equatable {
    public var id: UUID = .init()
    public var place: GooglePlacesSearchResponsePlace?
    
    public init(place: GooglePlacesSearchResponsePlace? = nil) {
        self.place = place
    }
    
    public static func == (lhs: GooglePlacesSearchPlaceWrapper, rhs: GooglePlacesSearchPlaceWrapper) -> Bool {
        return lhs.place?.id == rhs.place?.id
    }
}

// MARK: - Google Places Search request paramaters
public struct GooglePlacesNearbySearchParamater: Codable {
    var requestParamater: GooglePlacesNearbySearchBodyParamater
    var fieldMask: String
    var clientParamater: PlaceSearchClientParamater
    
    enum CodingKeys: String, CodingKey {
        case requestParamater = "request_paramater"
        case fieldMask = "field_mask"
        case clientParamater = "client_paramater"
    }
}

public struct PlaceSearchClientParamater: Codable {
    var latitude: Double
    var longitude: Double
    var windowWidth: CGFloat
    var windowHeight: CGFloat
    var mapZoomLevel: Int
    var resultOffset: Int
    var resultLimit: Int
 
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case windowWidth = "window_width"
        case windowHeight = "window_height"
        case mapZoomLevel = "map_zoom_level"
        case resultOffset = "result_offset"
        case resultLimit = "result_limit"
    }
    
    public init(latitude: Double, longitude: Double, zoom: Int, windowSize: CGSize, scale: CGFloat, offset: Int = 0, limit: Int = 10) {
        self.latitude = latitude
        self.longitude = longitude
        self.windowWidth = windowSize.width * scale
        self.windowHeight = windowSize.height * scale
        
        self.mapZoomLevel = zoom
        self.resultOffset = offset
        self.resultLimit = limit
    }
}

public struct GooglePlacesPlaceDetailBodyParamater: Codable {
    var fieldMask: String
    var placeIds: [String]
    var languageCode: String?
    var regionCode: String?
    var sessionToken: String?
    
    public init(fieldMask: String,
                placeIds: [String],
                languageCode: String? = nil,
                regionCode: String? = nil,
                sessionToken: String? = nil) {
        self.fieldMask = fieldMask
        self.placeIds = placeIds
        self.languageCode = languageCode
        self.regionCode = regionCode
        self.sessionToken = sessionToken
    }
    
    enum CodingKeys: String, CodingKey {
        case fieldMask = "field_mask"
        case placeIds = "place_ids"
        case languageCode = "language_code"
        case regionCode = "region_code"
        case sessionToken = "session_token"
    }
}

public struct GooglePlacesNearbySearchBodyParamater: Codable {
    var includedTypes: [GooglePlaceType]?
    var excludedTypes: [GooglePlaceType]?
    var includedPrimaryTypes: [GooglePrimaryPlaceType]?
    var excludedPrimaryTypes: [GooglePrimaryPlaceType]?
    var maxResultCount: Int?
    var languageCode: String?
    var rankPreference: String?
    var regionCode: String?
    var locationRestriction: LocationRestriction
    
    public init(
        includedTypes: [GooglePlaceType]? = nil,
        excludedTypes: [GooglePlaceType]? = nil,
        includedPrimaryTypes: [GooglePrimaryPlaceType]? = nil,
        excludedPrimaryTypes: [GooglePrimaryPlaceType]? = nil,
        maxResultCount: Int? = nil,
        languageCode: String? = nil,
        rankPreference: String? = nil,
        regionCode: String? = nil,
        locationRestriction: LocationRestriction
    ) {
        self.includedTypes = includedTypes
        self.excludedTypes = excludedTypes
        self.includedPrimaryTypes = includedPrimaryTypes
        self.excludedPrimaryTypes = excludedPrimaryTypes
        self.maxResultCount = maxResultCount
        self.languageCode = languageCode
        self.rankPreference = rankPreference
        self.regionCode = regionCode
        self.locationRestriction = locationRestriction
    }
}

public struct LocationRestriction: Codable {
    var circle: LocationCircle
}

public struct LocationCircle: Codable {
    var center: Center
    var radius: Double
    
    public init(latitude: CLLocationDegrees, longitude: CLLocationDegrees, radius: Double) {
        self.center = Center(latitude: latitude, longitude: longitude)
        self.radius = radius
    }
}

public struct Center: Codable {
    var latitude: Double
    var longitude: Double
}

public enum GooglePlaceType: String, Codable {
    // Automotive
    case carDealer = "car_dealer"
    case carRental = "car_rental"
    case carRepair = "car_repair"
    case carWash = "car_wash"
    case electricVehicleChargingStation = "electric_vehicle_charging_station"
    case station = "station"
    case gasStation = "gas_station"
    case parking = "parking"
    case restStop = "rest_stop"

    // Business
    case corporateOffice = "corporate_office"
    case farm = "farm"
    case ranch = "ranch"

    // Culture
    case artGallery = "art_gallery"
    case artStudio = "art_studio"
    case auditorium = "auditorium"
    case culturalLandmark = "cultural_landmark"
    case historicalPlace = "historical_place"
    case monument = "monument"
    case museum = "museum"
    case performingArtsTheater = "performing_arts_theater"
    case sculpture = "sculpture"
    
    // Education
    case library = "library"
    case preschool = "preschool"
    case primarySchool = "primary_school"
    case school = "school"
    case secondarySchool = "secondary_school"
    case university = "university"

    // Entertainment and Recreation
    case adventureSportsCenter = "adventure_sports_center"
    case amphitheatre = "amphitheatre"
    case amusementCenter = "amusement_center"
    case amusementPark = "amusement_park"
    case aquarium = "aquarium"
    case banquetHall = "banquet_hall"
    case barbecueArea = "barbecue_area"
    case botanicalGarden = "botanical_garden"
    case bowlingAlley = "bowling_alley"
    case casino = "casino"
    case childrensCamp = "childrens_camp"
    case comedyClub = "comedy_club"
    case communityCenter = "community_center"
    case concertHall = "concert_hall"
    case conventionCenter = "convention_center"
    case culturalCenter = "cultural_center"
    case cyclingPark = "cycling_park"
    case danceHall = "dance_hall"
    case dogPark = "dog_park"
    case eventVenue = "event_venue"
    case ferrisWheel = "ferris_wheel"
    case garden = "garden"
    case hikingArea = "hiking_area"
    case historicalLandmark = "historical_landmark"
    case internetCafe = "internet_cafe"
    case karaoke = "karaoke"
    case marina = "marina"
    case movieRental = "movie_rental"
    case movieTheater = "movie_theater"
    case nationalPark = "national_park"
    case nightClub = "night_club"
    case observationDeck = "observation_deck"
    case offRoadingArea = "off_roading_area"
    case operaHouse = "opera_house"
    case park = "park"
    case philharmonicHall = "philharmonic_hall"
    case picnicGround = "picnic_ground"
    case planetarium = "planetarium"
    case plaza = "plaza"
    case rollerCoaster = "roller_coaster"
    case skateboardPark = "skateboard_park"
    case statePark = "state_park"
    case touristAttraction = "tourist_attraction"
    case videoArcade = "video_arcade"
    case visitorCenter = "visitor_center"
    case waterPark = "water_park"
    case weddingVenue = "wedding_venue"
    case wildlifePark = "wildlife_park"
    case wildlifeRefuge = "wildlife_refuge"
    case zoo = "zoo"
    
    // Facilities
    case publicBath = "public_bath"
    case publicBathroom = "public_bathroom"
    case stable = "stable"
    
    // Finance
    case accounting = "accounting"
    case atm = "atm"
    case bank = "bank"

    // Food and Drink
    case acaiShop = "acai_shop"
    case afghaniRestaurant = "afghani_restaurant"
    case africanRestaurant = "african_restaurant"
    case americanRestaurant = "american_restaurant"
    case asianRestaurant = "asian_restaurant"
    case bagelShop = "bagel_shop"
    case bakery = "bakery"
    case bar = "bar"
    case barAndGrill = "bar_and_grill"
    case barbecueRestaurant = "barbecue_restaurant"
    case brazilianRestaurant = "brazilian_restaurant"
    case breakfastRestaurant = "breakfast_restaurant"
    case brunchRestaurant = "brunch_restaurant"
    case buffetRestaurant = "buffet_restaurant"
    case cafe = "cafe"
    case cafeteria = "cafeteria"
    case candyStore = "candy_store"
    case catCafe = "cat_cafe"
    case chineseRestaurant = "chinese_restaurant"
    case chocolateFactory = "chocolate_factory"
    case chocolateShop = "chocolate_shop"
    case coffeeShop = "coffee_shop"
    case confectionery = "confectionery"
    case deli = "deli"
    case dessertRestaurant = "dessert_restaurant"
    case dessertShop = "dessert_shop"
    case diner = "diner"
    case dogCafe = "dog_cafe"
    case donutShop = "donut_shop"
    case fastFoodRestaurant = "fast_food_restaurant"
    case fineDiningRestaurant = "fine_dining_restaurant"
    case foodCourt = "food_court"
    case food = "food"
    case frenchRestaurant = "french_restaurant"
    case greekRestaurant = "greek_restaurant"
    case hamburgerRestaurant = "hamburger_restaurant"
    case iceCreamShop = "ice_cream_shop"
    case indianRestaurant = "indian_restaurant"
    case indonesianRestaurant = "indonesian_restaurant"
    case italianRestaurant = "italian_restaurant"
    case japaneseRestaurant = "japanese_restaurant"
    case juiceShop = "juice_shop"
    case koreanRestaurant = "korean_restaurant"
    case lebaneseRestaurant = "lebanese_restaurant"
    case mealDelivery = "meal_delivery"
    case mealTakeaway = "meal_takeaway"
    case mediterraneanRestaurant = "mediterranean_restaurant"
    case mexicanRestaurant = "mexican_restaurant"
    case middleEasternRestaurant = "middle_eastern_restaurant"
    case pizzaRestaurant = "pizza_restaurant"
    case pub = "pub"
    case ramenRestaurant = "ramen_restaurant"
    case restaurant = "restaurant"
    case sandwichShop = "sandwich_shop"
    case seafoodRestaurant = "seafood_restaurant"
    case spanishRestaurant = "spanish_restaurant"
    case steakHouse = "steak_house"
    case sushiRestaurant = "sushi_restaurant"
    case teaHouse = "tea_house"
    case thaiRestaurant = "thai_restaurant"
    case turkishRestaurant = "turkish_restaurant"
    case veganRestaurant = "vegan_restaurant"
    case vietnameseRestaurant = "vietnamese_restaurant"
    case wineBar = "wine_bar"
    case izakaya = "izakaya"
    
    // Geographical Area
    case administrativeAreaLevel1 = "administrative_area_level_1"
    case administrativeAreaLevel2 = "administrative_area_level_2"
    case country = "country"
    case locality = "locality"
    case postalCode = "postal_code"
    case schoolDistrict = "school_district"
    
    // Government
    case cityHall = "city_hall"
    case courthouse = "courthouse"
    case embassy = "embassy"
    case fireStation = "fire_station"
    case governmentOffice = "government_office"
    case localGovernmentOffice = "local_government_office"
    case neighborhoodPoliceStation = "neighborhood_police_station"
    case police = "police"
    case postOffice = "post_office"
    
    // Health and Wellness
    case chiropractor = "chiropractor"
    case dentalClinic = "dental_clinic"
    case dentist = "dentist"
    case doctor = "doctor"
    case drugstore = "drugstore"
    case hospital = "hospital"
    case massage = "massage"
    case medicalLab = "medical_lab"
    case pharmacy = "pharmacy"
    case physiotherapist = "physiotherapist"
    case sauna = "sauna"
    case skinCareClinic = "skin_care_clinic"
    case spa = "spa"
    case tanningStudio = "tanning_studio"
    case wellnessCenter = "wellness_center"
    case yogaStudio = "yoga_studio"
    
    // Housing
    case apartmentBuilding = "apartment_building"
    case apartmentComplex = "apartment_complex"
    case condominiumComplex = "condominium_complex"
    case housingComplex = "housing_complex"
    
    // Lodging
    case bedAndBreakfast = "bed_and_breakfast"
    case budgetJapaneseInn = "budget_japanese_inn"
    case campground = "campground"
    case campingCabin = "camping_cabin"
    case cottage = "cottage"
    case extendedStayHotel = "extended_stay_hotel"
    case farmstay = "farmstay"
    case guestHouse = "guest_house"
    case hostel = "hostel"
    case hotel = "hotel"
    case inn = "inn"
    case japaneseInn = "japanese_inn"
    case lodging = "lodging"
    case mobileHomePark = "mobile_home_park"
    case motel = "motel"
    case privateGuestRoom = "private_guest_room"
    case resortHotel = "resort_hotel"
    case rvPark = "rv_park"
    
    // Natural Features
    case beach = "beach"
    case island = "island"
    case lake = "lake"
    
    // Places of Worship
    case church = "church"
    case hinduTemple = "hindu_temple"
    case mosque = "mosque"
    case synagogue = "synagogue"
    
    // Services
    case astrologer = "astrologer"
    case barberShop = "barber_shop"
    case beautician = "beautician"
    case beautySalon = "beauty_salon"
    case bodyArtService = "body_art_service"
    case cateringService = "catering_service"
    case cemetery = "cemetery"
    case childCareAgency = "child_care_agency"
    case consultant = "consultant"
    case courierService = "courier_service"
    case electrician = "electrician"
    case florist = "florist"
    case foodDelivery = "food_delivery"
    case footCare = "foot_care"
    case funeralHome = "funeral_home"
    case hairCare = "hair_care"
    case insuranceAgency = "insurance_agency"
    case laundry = "laundry"
    case lawyer = "lawyer"
    case locksmith = "locksmith"
    case markupArtist = "markup_artist"
    case movingCompany = "moving_company"
    case nailSalon = "nail_salon"
    case painter = "painter"
    case plumber = "plumber"
    case psychic = "psychic"
    case realEstateAgency = "real_estate_agency"
    case roofingContractor = "roofing_contractor"
    case storage = "storage"
    case summerCampOrganizer = "summer_camp_organizer"
    case tailor = "tailor"
    case telecommunicationsServiceProvider = "telecommunications_service_provider"
    case tourAgency = "tour_agency"
    case touristInformationCenter = "tourist_information_center"
    case travelAgency = "travel_agency"
    case veterinaryCafe = "veterinary_cafe"
    
    // Shopping
    case asianGroceryStore = "asian_grocery_store"
    case autoPartsStore = "auto_parts_store"
    case bicycleStore = "bicycle_store"
    case bookStore = "book_store"
    case butcherShop = "butcher_shop"
    case cellPhoneStore = "cell_phone_store"
    case clothingStore = "clothing_store"
    case convenienceStore = "convenience_store"
    case departmentStore = "department_store"
    case discountStore = "discount_store"
    case electronicsStore = "electronics_store"
    case foodStore = "food_store"
    case furnitureStore = "furniture_store"
    case giftShop = "gift_shop"
    case groceryStore = "grocery_store"
    case hardwareStore = "hardware_store"
    case homeGoodsStore = "home_goods_store"
    case homeImprovementStore = "home_improvement_store"
    case jewelryStore = "jewelry_store"
    case liquorStore = "liquor_store"
    case market = "market"
    case petStore = "pet_store"
    case shopStore = "shop_store"
    case shoppingMall = "shopping_mall"
    case sportingGoodsStore = "sporting_goods_store"
    case store = "store"
    case supermarket = "supermarket"
    case warehouseStore = "warehouse_store"
    case wholesaler = "wholesaler"
    
    // Sports
    case arena = "arena"
    case athleticField = "athletic_field"
    case fishingCharter = "fishing_charter"
    case fishingPond = "fishing_pond"
    case fitnessCenter = "fitness_center"
    case golfCourse = "golf_course"
    case gym = "gym"
    case iceSkatingRink = "ice_skating_rink"
    case playground = "playground"
    case skiResort = "ski_resort"
    case sportsActivityLocation = "sports_activity_location"
    case sportsClub = "sports_club"
    case sportsCoaching = "sports_coaching"
    case sportsComplex = "sports_complex"
    case stadium = "stadium"
    case swimmingPool = "swimming_pool"
    
    // Transportation
    case airport = "airport"
    case airstrip = "airstrip"
    case busStation = "bus_station"
    case ferryTerminal = "ferry_terminal"
    case heliport = "heliport"
    case internationalAirport = "international_airport"
    case lightRailStation = "light_rail_station"
    case parkAndRide = "park_and_ride"
    case subwayStation = "subway_station"
    case taxiStand = "taxi_stand"
    case trainStation = "train_station"
    case transitDepot = "transit_depot"
    case transitStation = "transit_station"
    case truckStop = "truck_stop"
}

public enum GooglePrimaryPlaceType: String, Codable {
    case administrativeAreaLevel3 = "administrative_area_level_3"
    case administrativeAreaLevel4 = "administrative_area_level_4"
    case administrativeAreaLevel5 = "administrative_area_level_5"
    case administrativeAreaLevel6 = "administrative_area_level_6"
    case administrativeAreaLevel7 = "administrative_area_level_7"
    case archipelago
    case colloquialArea = "colloquial_area"
    case continent
    case establishment
    case finance
    case food
    case generalContractor = "general_contractor"
    case geocode
    case health
    case intersection
    case landmark
    case naturalFeature = "natural_feature"
    case neighborhood
    case placeOfWorship = "place_of_worship"
    case plusCode = "plus_code"
    case pointOfInterest = "point_of_interest"
    case political
    case postalCodePrefix = "postal_code_prefix"
    case postalCodeSuffix = "postal_code_suffix"
    case postalTown = "postal_town"
    case premise
    case route
    case streetAddress = "street_address"
    case sublocality
    case sublocalityLevel1 = "sublocality_level_1"
    case sublocalityLevel2 = "sublocality_level_2"
    case sublocalityLevel3 = "sublocality_level_3"
    case sublocalityLevel4 = "sublocality_level_4"
    case sublocalityLevel5 = "sublocality_level_5"
    case subpremise
    case townSquare = "town_square"
}

public enum GooglePlaceFieldMask: String, Codable {
    // Nearby Search Pro SKU
    case accessibilityOptions
    case addressComponents
    case addressDescriptor
    case adrFormatAddress
    case attributioins
    case businessStatus
    case containingPlaces
    case displayName
    case formattedAddress
    case googleMapsUri
    case googleMapsLinks
    case iconBackgroundColor
    case iconMaskBaseUri
    case id
    case location
    case name
    case movedPlace
    case movedPlaceId
    case photos
    case plusCode
    case postalAddress
    case primaryType
    case primaryTypeDisplayName
    case pureServiceAreaBusiness
    case shortFormattedAddress
    case subDesinations
    case types
    case utcOffsetMinutes
    case viewport
    
    // Nearby Search Enterprise SKu
    case currentOpeningHours
    case currentSecondaryOpeningHours
    case internationalPhoneNumber
    case nationalPhoneNumber
    case priceLevel
    case priceRange
    case rating
    case regularOpeningHours
    case regularSecondaryOpeningHours
    case userRatingCount
    case websiteUri
    
    // Nearby Search Enterprise + Atmosphere
    case allowsDogs
    case curbsidePickup
    case delivery
    case dineIn
    case editorialSummary
    case evChargeAmenitySummary
    case evChargeOptions
    case generativeSummary
    case goodForChildren
    case goodForGroups
    case goodForWatchingSports
    case liveMusic
    case menuForChildren
    case neighborhoodSummary
    case parkingOptions
    case paymentOptions
    case outdoorSeating
    case reservable
    case restroom
    case reviews
    case reviewSummary
    case servesBeer
    case servesBreakfast
    case servesBrunch
    case servesCocktails
    case servesDessert
    case servesDinner
    case servesLunch
    case servesVegetarianFood
    case servesWine
    case takeout
}

extension GooglePlaceFieldMask {
    static let defaultFieldMask: [GooglePlaceFieldMask] = [.displayName,
                                                           .formattedAddress,
                                                           .id,
                                                           .location,
                                                           .name,
                                                           .photos,
                                                           .types,
                                                           .rating]
    
    static let detailFieldMask: [GooglePlaceFieldMask] = [.displayName,
                                                          .formattedAddress,
                                                          .id,
                                                          .location,
                                                          .name,
                                                          .photos,
                                                          .types,
                                                          .rating,
                                                          .reviews,
                                                          .currentOpeningHours,
                                                          .currentSecondaryOpeningHours,
                                                          .regularOpeningHours,
                                                          .regularSecondaryOpeningHours,
                                                          .priceLevel,
                                                          .priceRange,
                                                          .websiteUri,
                                                          .userRatingCount]
}

// MARK: - Google Places Search Response
public struct GooglePlacesSearchResponsePlace: Codable {
    public var name: String?
    public var id: String?
    public var displayName: GooglePlacesSearchResponseLocalizedText?
    public var types: [String]?
    public var primaryType: String?
    public var primaryTypeDisplayName: GooglePlacesSearchResponseLocalizedText?
    public var nationalPhoneNumber: String?
    public var formattedAddress: String?
    public var shortFormattedAddress: String?
    public var postalAddress: GooglePlacesSearchResponsePostalAddress?
    public var addressComponents: [GooglePlacesSearchResponseAddressComponent]?
    public var plusCode: GooglePlacesSearchResponsePlusCode?
    public var location: GooglePlacesSearchResponseLatLng?
    public var viewport: GooglePlacesSearchResponseViewPort?
    public var rating: Double?
    public var googleMapsUrl: String?
    public var websiteUri: String?
    public var reviews: [GooglePlacesSearchResponseReview]?
    public var regularOpeningHours: GooglePlacesSearchResponseOpeningHour?
    public var timeZone: GooglePlacesSearchResponseTimeZone?
    public var photos: [GooglePlacesSearchResponsePhoto]?
    public var adrFormatAddress: String?
    public var businessStatus: GooglePlacesSearchResponseBusinessStatus?
    public var priceLevel: GooglePlacesSearchResponsePriceLevel?
    public var attributions: [GooglePlacesSearchResponseAttribution]?
    public var iconMaskBaseUri: String?
    public var iconBackgroundColor: String?
    public var currentOpeningHours: GooglePlacesSearchResponseOpeningHour?
    public var currentSecondaryOpeningHours: [GooglePlacesSearchResponseOpeningHour]?
    public var regularSecondaryOpeningHours: [GooglePlacesSearchResponseOpeningHour]?
    public var editorialSummary: GooglePlacesSearchResponseLocalizedText?
    public var paymentOptions: GooglePlacesSearchResponsePaymentOptions?
    public var parkingOptions: GooglePlacesSearchResponseParkingOptions?
    public var subDestinations: [GooglePlacesSearchResponseSubDestination]?
    public var fuelOptions: GooglePlacesSearchResponseFuelOptions?
    public var evChargeOptions: GooglePlacesSearchResponseEVChargeOptions?
    public var generativeSummary: GooglePlacesSearchResponseGenerativeSummary?
    public var containingPlaces: GooglePlacesSearchResponseContainingPlaces?
    public var addressDescriptor: GooglePlacesSearchResponseAddressDescriptor?
    public var googleMapsLinks: GooglePlacesSearchResponseGoogleMapsLinks?
    public var priceRange: GooglePlacesSearchResponsePriceRange?
    public var reviewSummary: GooglePlacesSearchResponseReviewSummary?
    public var evChargeAmenitySummary: GooglePlacesSearchResponseEvChargeAmenitySummary?
    public var neighborhoodSummary: GooglePlacesSearchResponseNeighborhoodSummary?
    public var consumerAlert: GooglePlacesSearchResponseConsumerAlert?
    public var movedPlace: String?
    public var movedPlaceId: String?
    public var utcOffsetMinutes: UInt64?
    public var userRatingCount: UInt64?
    public var takeout: Bool?
    public var delivery: Bool?
    public var dineIn: Bool?
    public var curbsidePickup: Bool?
    public var reservable: Bool?
    public var servesBreakfast: Bool?
    public var servesLunch: Bool?
    public var servesDinner: Bool?
    public var servesBeer: Bool?
    public var servesWine: Bool?
    public var servesBrunch: Bool?
    public var servesVegetarianFood: Bool?
    public var outdoorSeating: Bool?
    public var liveMusic: Bool?
    public var menuForChildren: Bool?
    public var servesCocktails: Bool?
    public var servesDessert: Bool?
    public var servesCoffee: Bool?
    public var goodForChildren: Bool?
    public var allowsDogs: Bool?
    public var restroom: Bool?
    public var goodForGroups: Bool?
    public var goodForWatchingSports: Bool?
    public var accessibilityOptions: GooglePlacesSearchResponseAccessibilityOptions?
    public var pureServiceAreaBusiness: Bool?
}

public struct GooglePlacesSearchResponseRoutingSummary: Codable, Hashable {
    public let legs: [GooglePlacesSearchResponseLeg]?
    public let directionsUri: String?
}

public struct GooglePlacesSearchResponseLeg: Codable, Hashable {
    public let duration: String?
    public let distanceMeters: Int64?
}

public struct GooglePlacesSearchResponseLocalizedText: Codable, Hashable {
    public let text: String?
    public let languageCode: String?
}

public struct GooglePlacesSearchResponsePostalAddress: Codable, Hashable {
    public let revision: String?
    public let regionCode: String?
    public let languageCode: String?
    public let postalCode: String?
    public let sortingCode: String?
    public let administrativeArea: String?
    public let locality: String?
    public let subLocality: String?
    public let addressLiens: [String]?
    public let recipients: [String]?
    public let organization: String?
}

public struct GooglePlacesSearchResponseAddressComponent: Codable, Hashable {
    public let longText: String?
    public let shortText: String?
    public let types: [String]?
    public let languageCode: String?
}

// MARK: Coordinates and Viewport
public struct GooglePlacesSearchResponsePlusCode: Codable, Hashable {
    public let globalCode: String?
    public let compoundCode: String?
}

public struct GooglePlacesSearchResponseLatLng: Codable, Hashable {
    public let latitude: Double?
    public let longitude: Double?
    
    public var lat: Double? {
        return latitude
    }
    
    public var lon: Double? {
        return longitude
    }
}

public struct GooglePlacesSearchResponseViewPort: Codable, Hashable {
    public let low: GooglePlacesSearchResponseLatLng?
    public let high: GooglePlacesSearchResponseLatLng?
}

// MARK: Reviews and Opening Hours
public struct GooglePlacesSearchResponseReview: Codable, Hashable {
    public let name: String?
    public let relativePublishTimeDescription: String?
    public let text: GooglePlacesSearchResponseLocalizedText?
    public let originalText: GooglePlacesSearchResponseLocalizedText?
    public let rating: UInt8?
    public let authorAttribution: GooglePlacesSearchResponseAuthorAttribution?
    public let publishTime: String?
    public let flagContentUri: String?
    public let googleMapsUri: String?
    public let visitDate: GooglePlacesSearchResponseDate?
}

public struct GooglePlacesSearchResponseAuthorAttribution: Codable, Hashable {
    public let displayName: String?
    public let uri: String?
    public let photoUri: String?
}

public struct GooglePlacesSearchResponseDate: Codable, Hashable {
    public let year: UInt16?
    public let month: UInt16?
    public let day: UInt16?
}

public struct GooglePlacesSearchResponseOpeningHour: Codable, Hashable {
    public let periods: [GooglePlacesSearchResponsePeriod]?
    public let weekdayDescriptions: [String]?
    public let secondayHoursType: GooglePlaceseSearchResponseSecondaryHoursType?
    public let specialDays: [GooglePlacesSearchResponseSpecialDay]?
    public let nextOpenTime: String?
    public let nextCloseTime: String?
    public let openNow: Bool?
}

public struct GooglePlacesSearchResponsePeriod: Codable, Hashable {
    public let open: GooglePlacesSearchResponsePoint?
    public let close: GooglePlacesSearchResponsePoint?
}

public struct GooglePlacesSearchResponsePoint: Codable, Hashable {
    public let date: GooglePlacesSearchResponseDate?
    public let truncated: Bool?
    public let day: UInt16?
    public let hour: UInt8?
    public let minute: UInt8?
}

public struct GooglePlacesSearchResponseSpecialDay: Codable, Hashable {
    public let date: GooglePlacesSearchResponseDate?
}

public struct GooglePlacesSearchResponseTimeZone: Codable, Hashable {
    public let id: String?
    public let version: String?
}

public struct GooglePlacesSearchResponsePhoto: Codable, Hashable, Identifiable {
    public var id: UUID = .init()
    public var name: String?
    public let widthPx: UInt32?
    public let heightPx: UInt32?
    public let authorAttributions: [GooglePlacesSearchResponseAuthorAttribution]?
    public let flagContentUri: String?
    public let googleMapsUri: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case widthPx
        case heightPx
        case authorAttributions
        case flagContentUri
        case googleMapsUri
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID() 
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.widthPx = try container.decodeIfPresent(UInt32.self, forKey: .widthPx)
        self.heightPx = try container.decodeIfPresent(UInt32.self, forKey: .heightPx)
        self.authorAttributions = try container.decodeIfPresent([GooglePlacesSearchResponseAuthorAttribution].self, forKey: .authorAttributions)
        self.flagContentUri = try container.decodeIfPresent(String.self, forKey: .flagContentUri)
        self.googleMapsUri = try container.decodeIfPresent(String.self, forKey: .googleMapsUri)
    }
}

extension GooglePlacesSearchResponsePhoto {
    public func buildUrl() -> URL {
        var baseEndpoint: String = .proxyEndPoint
        baseEndpoint = baseEndpoint + "/api/" + (self.name ?? "")
        baseEndpoint = baseEndpoint + "/media?maxWidthPx=\(min(500, self.widthPx ?? 500))&maxHeightPx=\(min(500, self.heightPx ?? 500))"
        return URL(string: baseEndpoint)!
    }
}

public struct GooglePlacesSearchResponseAttribution: Codable, Hashable {
    public let provider: String?
    public let providerUri: String?
}

public struct GooglePlacesSearchResponseMoney: Codable, Hashable {
    public let currencyCode: String?
    public let units: String?
    public let nanos: UInt32?
}

public struct GooglePlacesSearchResponsePaymentOptions: Codable, Hashable {
    public let acceptsCreditCards: Bool?
    public let acceptsDebitCards: Bool?
    public let acceptsCashOnly: Bool?
    public let acceptsNfc: Bool?
}

public struct GooglePlacesSearchResponseParkingOptions: Codable, Hashable {
    public let freeParkingLot: Bool?
    public let paidParkingLot: Bool?
    public let freeStreetParking: Bool?
    public let paidStreetParking: Bool?
    public let valetParking: Bool?
    public let freeGarageParking: Bool?
    public let paidGarageParking: Bool?
}

public struct GooglePlacesSearchResponseSubDestination: Codable, Hashable {
    public let name: String?
    public let id: String?
}

public struct GooglePlacesSearchResponseFuelOptions: Codable, Hashable {
    public let fuelPrices: [GooglePlacesSearchResponseFuelPrice]?
}

public struct GooglePlacesSearchResponseFuelPrice: Codable, Hashable {
    public let typeProp: GooglePlacesSearchResponseFuelType?
    public let price: GooglePlacesSearchResponseMoney?
    public let updateTime: String?

    private enum CodingKeys: String, CodingKey {
        case typeProp = "type"
        case price, updateTime
    }
}

public struct GooglePlacesSearchResponseEVChargeOptions: Codable, Hashable {
    public let connectorCount: UInt64?
    public let connectorAggregation: [GooglePlacesSearchResponseConnectorAggregation]?
}

public struct GooglePlacesSearchResponseConnectorAggregation: Codable, Hashable {
    public let typeProp: GooglePlacesSearchResponseEVConnectorType?
    public let maxChargeRateKw: Double?
    public let count: UInt64?
    public let availabilityLastUpdateTime: String?
    public let availableCount: UInt64?
    public let outOfServiceCount: UInt64?

    private enum CodingKeys: String, CodingKey {
        case typeProp = "type"
        case maxChargeRateKw, count, availabilityLastUpdateTime, availableCount, outOfServiceCount
    }
}

public struct GooglePlacesSearchResponseGenerativeSummary: Codable, Hashable {
    public let overview: GooglePlacesSearchResponseLocalizedText?
    public let overviewFlagContentUri: String?
    public let disclosureText: GooglePlacesSearchResponseLocalizedText?
}

public struct GooglePlacesSearchResponseContainingPlaces: Codable, Hashable {
    public let name: String?
    public let id: String?
}

public struct GooglePlacesSearchResponseAddressDescriptor: Codable, Hashable {
    public let landmarks: [GooglePlacesSearchResponseLandmark]?
    public let areas: [GooglePlacesSearchResponseArea]?
}

public struct GooglePlacesSearchResponseLandmark: Codable, Hashable {
    public let name: String?
    public let placeId: String?
    public let displayName: GooglePlacesSearchResponseLocalizedText?
    public let types: [String]?
    public let spatialRelationship: GooglePlacesSearchResponseSpatialRelationship?
}

public struct GooglePlacesSearchResponseArea: Codable, Hashable {
    public let name: String?
    public let placeId: String?
    public let displayName: GooglePlacesSearchResponseLocalizedText?
    public let containment: GooglePlacesSearchResponseContainment?
}

public struct GooglePlacesSearchResponseGoogleMapsLinks: Codable, Hashable {
    public let directionUri: String?
    public let placeUri: String?
    public let writeAReviewUri: String?
    public let reviwsUri: String?
    public let photoUri: String?
}

public struct GooglePlacesSearchResponsePriceRange: Codable, Hashable {
    public let startPrice: GooglePlacesSearchResponseMoney?
    public let endPrice: GooglePlacesSearchResponseMoney?
}

public struct GooglePlacesSearchResponseReviewSummary: Codable, Hashable {
    public let text: GooglePlacesSearchResponseLocalizedText?
    public let flagContentUri: String?
    public let disclosureText: GooglePlacesSearchResponseLocalizedText?
    public let reviewsUri: String?
}

public struct GooglePlacesSearchResponseEvChargeAmenitySummary: Codable, Hashable {
    public let overview: GooglePlacesSearchResponseContentBlock?
    public let coffee: GooglePlacesSearchResponseContentBlock?
    public let restaurant: GooglePlacesSearchResponseContentBlock?
    public let store: GooglePlacesSearchResponseContentBlock?
    public let flagContentUri: String?
    public let disclosureText: GooglePlacesSearchResponseLocalizedText?
}

public struct GooglePlacesSearchResponseContentBlock: Codable, Hashable {
    public let content: GooglePlacesSearchResponseLocalizedText?
    public let referencedPlaces: [String]?
}

public struct GooglePlacesSearchResponseNeighborhoodSummary: Codable, Hashable {
    public let overview: GooglePlacesSearchResponseContentBlock?
    public let description: GooglePlacesSearchResponseContentBlock?
    public let flagContentUri: String?
    public let disclosureText: GooglePlacesSearchResponseLocalizedText?
}

public struct GooglePlacesSearchResponseConsumerAlert: Codable, Hashable {
    public let overview: String?
    public let details: GooglePlacesSearchResponseDetails?
}

public struct GooglePlacesSearchResponseDetails: Codable, Hashable {
    public let title: String?
    public let description: String?
    public let aboutLink: GooglePlacesSearchResponseLink?
}

public struct GooglePlacesSearchResponseLink: Codable, Hashable {
    public let title: String?
    public let uri: String?
}

public struct GooglePlacesSearchResponseAccessibilityOptions: Codable, Hashable {
    public let wheelchairAccessibleParking: Bool?
    public let wheelchairAccessibleEntrance: Bool?
    public let wheelchairAccessibleRestroom: Bool?
    public let wheelchairAccessibleSeating: Bool?
}

public enum GooglePlaceseSearchResponseSecondaryHoursType: String, Codable, Hashable {
    case unspecified = "SECONDARY_HOURS_TYPE_UNSPECIFIED"
    case driveThrough = "DRIVE_THROUGH"
    case happyHour = "HAPPY_HOUR"
    case delivery = "DELIVERY"
    case takeout = "TAKEOUT"
    case kitchen = "KITCHEN"
    case breakfast = "BREAKFAST"
    case lunch = "LUNCH"
    case dinner = "DINNER"
    case brunch = "BRUNCH"
    case pickup = "PICKUP"
    case access = "ACCESS"
    case seniorHours = "SENIOR_HOURS"
    case onlineServiceHours = "ONLINE_SERVICE_HOURS"
    
    public init(from decoder: Decoder) {
        do {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            if let value = GooglePlaceseSearchResponseSecondaryHoursType(rawValue: rawValue) {
                self = value
            } else {
                self = .unspecified
            }
        } catch {
            self = .unspecified
        }
    }
}

public enum GooglePlacesSearchResponseFuelType: String, Codable, Hashable {
    case unspecified = "FUEL_TYPE_UNSPECIFIED"
    case diesel = "DIESEL"
    case dieselPlus = "DIESEL_PLUS"
    case regularUnleaded = "REGULAR_UNLEADED"
    case midgrade = "MIDGRADE"
    case premium = "PREMIUM"
    case sp91 = "SP91"
    case sp91e10 = "SP91_E10"
    case sp92 = "SP92"
    case sp95 = "SP95"
    case sp95e10 = "SP95_E10"
    case sp98 = "SP98"
    case sp99 = "SP99"
    case sp100 = "SP100"
    case lpg = "LPG"
    case e80 = "E80"
    case e85 = "E85"
    case e100 = "E100"
    case methane = "METHANE"
    case bioDiesel = "BIO_DIESEL"
    case truckDiesel = "TRUCK_DIESEL"
}

public enum GooglePlacesSearchResponseEVConnectorType: String, Codable, Hashable {
    case unspecified = "EV_CONNECTOR_TYPE_UNSPECIFIED"
    case other = "EV_CONNECTOR_TYPE_OTHER"
    case j1771 = "EV_CONNECTOR_TYPE_J1771"
    case type2 = "EV_CONNECTOR_TYPE_TYPE_2"
    case chademo = "EV_CONNECTOR_TYPE_CHADEMO"
    case ccsCombo1 = "EV_CONNECTOR_TYPE_CCS_COMBO_1"
    case ccsCombo2 = "EV_CONNECTOR_TYPE_CCS_COMBO_2"
    case tesla = "EV_CONNECTOR_TYPE_TESLA"
}

public enum GooglePlacesSearchResponseBusinessStatus: String, Codable, Hashable {
    case unspecified = "BUSINESS_STATUS_UNSPECIFIED"
    case operational = "OPERATIONAL"
    case closedTemporarily = "CLOSED_TEMPORARILY"
    case closedPermanently = "CLOSED_PERMANENTLY"
}

public enum GooglePlacesSearchResponsePriceLevel: String, Codable, Hashable {
    case unspecified = "PRICE_LEVEL_UNSPECIFIED"
    case free = "PRICE_LEVEL_FREE"
    case inexpensive = "PRICE_LEVEL_INEXPENSIVE"
    case moderate = "PRICE_LEVEL_MODERATE"
    case expensive = "PRICE_LEVEL_EXPENSIVE"
    case veryExpensive = "PRICE_LEVEL_VERY_EXPENSIVE"
}

public enum GooglePlacesSearchResponseSpatialRelationship: String, Codable, Hashable {
    case near = "NEAR"
    case within = "WITHIN"
    case beside = "BESIDE"
    case acrossTheRoad = "ACROSS_THE_ROAD"
    case downTheRoad = "DOWN_THE_ROAD"
    case aroundTheCorner = "AROUND_THE_CORNER"
    case behind = "BEHIND"
}

public enum GooglePlacesSearchResponseContainment: String, Codable, Hashable {
    case unspecified = "CONTAINMENT_UNSPECIFIED"
    case within = "WITHIN"
    case outskirts = "OUTSKIRTS"
    case near = "NEAR"
}
