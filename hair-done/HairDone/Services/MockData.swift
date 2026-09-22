import Foundation

/// Seeded, deterministic data so the app demos the same way every time.
/// Melbourne inner north and south. Names, bios and reviews are written in the app's voice.
enum MockData {
    static let now = Date()
    static func daysAgo(_ n: Int) -> Date { now.adding(days: -n) }

    // MARK: Client (you)

    static let clientID = "client_tash"
    static let client = Client(
        id: clientID,
        firstName: "Tash",
        lastName: "Okafor",
        phone: "0412 555 019",
        email: "tash@example.com",
        addresses: [
            Address(id: "addr_home", label: "Home", line1: "14 Rae St", suburb: "Fitzroy North", postcode: "3068", latitude: -37.7852, longitude: 144.9776, instructions: "Blue door, buzz 2. Dog is friendly."),
            Address(id: "addr_work", label: "Work", line1: "Level 3, 120 Collins St", suburb: "Melbourne", postcode: "3000", latitude: -37.8138, longitude: 144.9705, instructions: "Reception will send you up.")
        ],
        paymentMethods: [
            PaymentMethod(id: "pm_apple", kind: .applePay, brand: "Apple Pay", last4: "", expiry: "", isDefault: true),
            PaymentMethod(id: "pm_visa", kind: .card, brand: "Visa", last4: "4242", expiry: "09/28", isDefault: false)
        ],
        favouriteProIDs: ["pro_kiara", "pro_mei"],
        seed: 7,
        joined: daysAgo(140)
    )

    // MARK: Pros

    static let pros: [Pro] = [
        Pro(id: "pro_kiara", firstName: "Kiara", lastInitial: "M", specialties: [.nails],
            headline: "Nails, done properly, at your kitchen table.",
            bio: "Eight years in salons in Brunswick and Carlton before I went mobile. I bring the lamp, the table, the lot. BIAB is my thing, but I'll do anything from a tidy-up to full chrome. Tell me what you're wearing and I'll match it.",
            suburb: "Brunswick", latitude: -37.7667, longitude: 144.9600, travelRadiusKm: 8, travelFeeCents: 1500,
            rating: 4.9, reviewCount: 212, isVerified: true, instantBook: true, yearsExperience: 8, responseMinutes: 12, joined: daysAgo(400),
            services: [
                Service(id: "s_k1", name: "BIAB overlay", category: .nails, priceCents: 9500, minutes: 75, detail: "Builder gel on your natural nail. Strong, not thick. Lasts three to four weeks.", isPopular: true),
                Service(id: "s_k2", name: "Gel manicure", category: .nails, priceCents: 7000, minutes: 60, detail: "Shape, cuticles, gel colour. Plain or with a bit of art."),
                Service(id: "s_k3", name: "Full set acrylics", category: .nails, priceCents: 13000, minutes: 105, detail: "Sculpted, any length. French, ombre, chrome, whatever you've saved on your phone."),
                Service(id: "s_k4", name: "Gel pedicure", category: .nails, priceCents: 8000, minutes: 60, detail: "Soak, scrub, shape, colour. Bring a towel, I bring the rest."),
                Service(id: "s_k5", name: "Removal + tidy", category: .nails, priceCents: 4000, minutes: 40, detail: "Soak-off done gently, then a shape and cuticle oil.")
            ],
            work: works(seed: 11, category: .nails, captions: ["French, but longer", "Chrome on a short almond", "BIAB, milky pink", "Full set, coffin, cherry red", "Tortoiseshell on a square", "Bridal set for Ana", "Micro French, gel", "Ombre, nude to white", "Cat eye, deep green"]),
            reviews: [
                Review(id: "r_k1", clientFirstName: "Priya", rating: 5, text: "Came to my flat at 7am before a wedding and did not rush a single nail. Still perfect three weeks later.", date: daysAgo(4), serviceName: "BIAB overlay"),
                Review(id: "r_k2", clientFirstName: "Georgia", rating: 5, text: "She matched the exact red from a photo I sent. Set up and packed down in five minutes each end.", date: daysAgo(11), serviceName: "Full set acrylics", proReply: "That red is now in my kit permanently. Thank you Georgia."),
                Review(id: "r_k3", clientFirstName: "Hannah", rating: 4, text: "Lovely, quick, tidy. Only thing is she was about 15 minutes late because of Sydney Rd traffic, but she messaged ahead.", date: daysAgo(26), serviceName: "Gel manicure"),
                Review(id: "r_k4", clientFirstName: "Amira", rating: 5, text: "My mum is 78 and can't get to a salon anymore. Kiara does her nails every month now. Patient, kind, brilliant.", date: daysAgo(40), serviceName: "Gel pedicure"),
                Review(id: "r_k5", clientFirstName: "Zoe", rating: 5, text: "Chrome. Perfect chrome. That's the review.", date: daysAgo(61), serviceName: "Gel manicure")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(9, 18)], .tuesday: [.hours(9, 18)], .wednesday: [.hours(9, 20)], .thursday: [.hours(9, 20)], .friday: [.hours(8, 21)], .saturday: [.hours(7, 20)]]),
            seed: 11, completedBookings: 640, abn: "51 824 753 556", payoutsConnected: true),

        Pro(id: "pro_mei", firstName: "Mei", lastInitial: "L", specialties: [.hair, .theLot],
            headline: "Blow-dries that survive the night. Bridal parties a specialty.",
            bio: "Fifteen years behind the chair, the last four on the road with a kit that fits in a Yaris. I do event hair, colour touch-ups and cuts at home. For weddings I bring a second pair of hands so nobody's waiting.",
            suburb: "Northcote", latitude: -37.7700, longitude: 145.0000, travelRadiusKm: 12, travelFeeCents: 2000,
            rating: 4.8, reviewCount: 158, isVerified: true, instantBook: false, yearsExperience: 15, responseMinutes: 35, joined: daysAgo(310),
            services: [
                Service(id: "s_m1", name: "Blow-dry", category: .hair, priceCents: 8500, minutes: 50, detail: "Wash at yours, then a proper blow-dry. Bouncy, sleek or beachy.", isPopular: true),
                Service(id: "s_m2", name: "Event hair", category: .hair, priceCents: 14000, minutes: 75, detail: "Up, half-up, waves, braids. Send me a photo and I'll tell you if it'll hold."),
                Service(id: "s_m3", name: "Cut + blow-dry", category: .hair, priceCents: 12000, minutes: 70, detail: "Consult, cut, finish. Kitchen chair, good light, no salon small talk unless you want it."),
                Service(id: "s_m4", name: "Root touch-up", category: .hair, priceCents: 13500, minutes: 90, detail: "Regrowth colour to match. Bring a photo of your last colour if it wasn't me."),
                Service(id: "s_m5", name: "Hair + makeup", category: .theLot, priceCents: 26000, minutes: 130, detail: "Both, one visit, one person. Book two weeks out for weekends.")
            ],
            work: works(seed: 23, category: .hair, captions: ["Old Hollywood waves", "Textured low bun", "Bouncy blow-dry", "Bridal half-up", "Copper gloss", "Box braids, mid-back", "Sleek pony", "Balayage refresh", "Curtain bangs cut"]),
            reviews: [
                Review(id: "r_m1", clientFirstName: "Laura", rating: 5, text: "Did five of us for my sister's wedding out of my parents' bathroom. Calm the whole time. Hair lasted until 2am.", date: daysAgo(7), serviceName: "Event hair"),
                Review(id: "r_m2", clientFirstName: "Bec", rating: 5, text: "Best blow-dry I've had in Melbourne and I didn't have to put shoes on.", date: daysAgo(19), serviceName: "Blow-dry"),
                Review(id: "r_m3", clientFirstName: "Sunita", rating: 4, text: "Great cut. She's honest about what your hair will and won't do, which I appreciated.", date: daysAgo(33), serviceName: "Cut + blow-dry")
            ],
            availability: WeeklyAvailability(hours: [.tuesday: [.hours(10, 19)], .wednesday: [.hours(10, 19)], .thursday: [.hours(10, 21)], .friday: [.hours(7, 21)], .saturday: [.hours(6, 21)], .sunday: [.hours(8, 16)]]),
            seed: 23, completedBookings: 410, abn: "72 118 340 902", payoutsConnected: true),

        Pro(id: "pro_ruby", firstName: "Ruby", lastInitial: "A", specialties: [.makeup, .theLot],
            headline: "Makeup that looks like you, on a very good day.",
            bio: "Trained in Sydney, worked backstage at fashion week, now I mostly do weddings, birthdays and the occasional Tuesday. Skin first, then whatever you want on top. I carry every shade.",
            suburb: "Collingwood", latitude: -37.8020, longitude: 144.9880, travelRadiusKm: 10, travelFeeCents: 1500,
            rating: 5.0, reviewCount: 96, isVerified: true, instantBook: true, yearsExperience: 9, responseMinutes: 20, joined: daysAgo(220),
            services: [
                Service(id: "s_r1", name: "Event makeup", category: .makeup, priceCents: 15000, minutes: 60, detail: "Full face for a night out, a shoot, a wedding you're a guest at. Lashes included.", isPopular: true),
                Service(id: "s_r2", name: "Bridal makeup", category: .makeup, priceCents: 28000, minutes: 90, detail: "Includes a trial two to four weeks out. Long-wear, photographs well, survives crying."),
                Service(id: "s_r3", name: "Soft glam", category: .makeup, priceCents: 12000, minutes: 45, detail: "Skin, brows, a bit of lash. You, but rested."),
                Service(id: "s_r4", name: "Makeup lesson", category: .makeup, priceCents: 18000, minutes: 90, detail: "Your face, your products, my hands on yours. You leave knowing how to do it."),
                Service(id: "s_r5", name: "Hair + makeup", category: .theLot, priceCents: 27000, minutes: 120, detail: "I bring a hair stylist I trust. One booking, two of us.")
            ],
            work: works(seed: 37, category: .makeup, captions: ["Bridal, dewy", "Smoky, for Alina's 30th", "Fresh skin, freckles kept", "Red lip, nothing else", "Editorial for a shoot", "Soft glam, brown eye", "Graphic liner", "Mother of the bride", "Glitter cut crease"]),
            reviews: [
                Review(id: "r_r1", clientFirstName: "Chloe", rating: 5, text: "I cried at the ceremony, the reception and in the car home. Makeup did not move.", date: daysAgo(9), serviceName: "Bridal makeup"),
                Review(id: "r_r2", clientFirstName: "Tara", rating: 5, text: "Asked for 'like me but better' and that's exactly what I got. Nobody asked if I was wearing makeup, three people asked if I'd been on holiday.", date: daysAgo(22), serviceName: "Soft glam"),
                Review(id: "r_r3", clientFirstName: "Nadia", rating: 5, text: "The lesson was worth every cent. I've finally stopped buying foundation that's the wrong colour.", date: daysAgo(48), serviceName: "Makeup lesson")
            ],
            availability: WeeklyAvailability(hours: [.wednesday: [.hours(12, 21)], .thursday: [.hours(12, 21)], .friday: [.hours(6, 22)], .saturday: [.hours(5, 22)], .sunday: [.hours(7, 18)]]),
            seed: 37, completedBookings: 230, abn: "33 902 114 778", payoutsConnected: true),

        Pro(id: "pro_sofia", firstName: "Sofia", lastInitial: "R", specialties: [.lashes, .brows],
            headline: "Lashes you'll forget aren't yours. Brows to match.",
            bio: "Lash tech for six years, brows for four. I'm gentle, I'm quick, and I won't glue your eyes shut. Lifts are my favourite thing to do because you wake up done.",
            suburb: "Richmond", latitude: -37.8183, longitude: 144.9980, travelRadiusKm: 9, travelFeeCents: 1000,
            rating: 4.9, reviewCount: 143, isVerified: true, instantBook: true, yearsExperience: 6, responseMinutes: 8, joined: daysAgo(350),
            services: [
                Service(id: "s_s1", name: "Lash lift + tint", category: .lashes, priceCents: 9000, minutes: 60, detail: "Your own lashes, curled and darkened. Six to eight weeks, no upkeep.", isPopular: true),
                Service(id: "s_s2", name: "Classic set", category: .lashes, priceCents: 12000, minutes: 90, detail: "One extension per lash. Natural, mascara-on-a-good-day."),
                Service(id: "s_s3", name: "Hybrid set", category: .lashes, priceCents: 14000, minutes: 105, detail: "Classic and volume mixed. Fuller, still soft."),
                Service(id: "s_s4", name: "Brow lamination + tint", category: .brows, priceCents: 8500, minutes: 50, detail: "Brushed up and set for six weeks. Includes a shape."),
                Service(id: "s_s5", name: "Brow shape + tint", category: .brows, priceCents: 4500, minutes: 30, detail: "Wax or thread, then tint. Quick, tidy.")
            ],
            work: works(seed: 41, category: .lashes, captions: ["Lift and tint, natural", "Hybrid, wispy", "Classic, cat-eye map", "Laminated brows", "Brow tint, soft arch", "Volume, doll map", "Lift on straight lashes", "Brow shape, henna", "Wet look set"]),
            reviews: [
                Review(id: "r_s1", clientFirstName: "Emily", rating: 5, text: "I fell asleep. Woke up with lashes. Ten out of ten.", date: daysAgo(3), serviceName: "Lash lift + tint"),
                Review(id: "r_s2", clientFirstName: "Jas", rating: 5, text: "Did my brows at the office in my lunch break. Set up in the meeting room. Nobody blinked.", date: daysAgo(15), serviceName: "Brow lamination + tint"),
                Review(id: "r_s3", clientFirstName: "Ayesha", rating: 4, text: "Really good set. Wish she had a Sunday slot but I get it.", date: daysAgo(29), serviceName: "Hybrid set")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(8, 19)], .tuesday: [.hours(8, 19)], .wednesday: [.hours(8, 19)], .thursday: [.hours(8, 21)], .friday: [.hours(8, 21)], .saturday: [.hours(8, 17)]]),
            seed: 41, completedBookings: 520, abn: "19 447 021 655", payoutsConnected: true),

        Pro(id: "pro_aaliyah", firstName: "Aaliyah", lastInitial: "B", specialties: [.hair],
            headline: "Braids, locs, silk presses. Textured hair is the whole job.",
            bio: "I grew up doing my sisters' hair on a Sunday and never really stopped. Knotless braids, twists, loc retwists, silk presses, protective styles for kids too. I bring my own chair and a good playlist.",
            suburb: "Footscray", latitude: -37.8000, longitude: 144.9000, travelRadiusKm: 15, travelFeeCents: 2500,
            rating: 4.9, reviewCount: 88, isVerified: true, instantBook: false, yearsExperience: 7, responseMinutes: 45, joined: daysAgo(180),
            services: [
                Service(id: "s_a1", name: "Knotless braids, mid-back", category: .hair, priceCents: 28000, minutes: 300, detail: "Hair included. Bring snacks, this is a long one.", isPopular: true),
                Service(id: "s_a2", name: "Silk press", category: .hair, priceCents: 14000, minutes: 120, detail: "Wash, treat, blow out, press. Swings."),
                Service(id: "s_a3", name: "Loc retwist", category: .hair, priceCents: 11000, minutes: 90, detail: "Wash, retwist, style. Add a colour rinse if you like."),
                Service(id: "s_a4", name: "Kids' braids", category: .hair, priceCents: 9000, minutes: 120, detail: "Under 12s. Gentle hands, cartoons allowed."),
                Service(id: "s_a5", name: "Twist-out", category: .hair, priceCents: 9500, minutes: 90, detail: "Defined, soft, lasts the week.")
            ],
            work: works(seed: 53, category: .hair, captions: ["Knotless, waist length", "Silk press, blunt", "Retwist with a fade", "Fulani braids with beads", "Passion twists", "Kids' cornrows", "Boho knotless", "Twist-out, big", "Goddess locs"]),
            reviews: [
                Review(id: "r_a1", clientFirstName: "Imani", rating: 5, text: "Five hours and my scalp didn't hurt once. Neatest parts I've ever had.", date: daysAgo(6), serviceName: "Knotless braids, mid-back"),
                Review(id: "r_a2", clientFirstName: "Grace", rating: 5, text: "My daughter actually sat still. That has never happened.", date: daysAgo(20), serviceName: "Kids' braids"),
                Review(id: "r_a3", clientFirstName: "Fatima", rating: 5, text: "Silk press lasted through a humid week. Witchcraft.", date: daysAgo(44), serviceName: "Silk press")
            ],
            availability: WeeklyAvailability(hours: [.thursday: [.hours(9, 20)], .friday: [.hours(9, 20)], .saturday: [.hours(7, 21)], .sunday: [.hours(8, 20)]]),
            seed: 53, completedBookings: 190, abn: "88 231 776 410", payoutsConnected: true),

        Pro(id: "pro_yasmin", firstName: "Yasmin", lastInitial: "H", specialties: [.makeup, .brows],
            headline: "Bold when you want it, barely there when you don't.",
            bio: "Makeup artist and brow tech. Big on Eid, Diwali and wedding season. I've done makeup for hijabi brides who want the full look and for mums who want ten minutes of peace and a nice brow. Both are the job.",
            suburb: "Coburg", latitude: -37.7450, longitude: 144.9640, travelRadiusKm: 12, travelFeeCents: 1500,
            rating: 4.7, reviewCount: 64, isVerified: true, instantBook: true, yearsExperience: 5, responseMinutes: 25, joined: daysAgo(150),
            services: [
                Service(id: "s_y1", name: "Event makeup", category: .makeup, priceCents: 13000, minutes: 60, detail: "Full face, lashes in, ready to go.", isPopular: true),
                Service(id: "s_y2", name: "Bridal makeup", category: .makeup, priceCents: 25000, minutes: 90, detail: "Trial included. I'll come to the venue."),
                Service(id: "s_y3", name: "Brow shape + tint", category: .brows, priceCents: 4000, minutes: 30, detail: "Thread and tint. Quick and neat."),
                Service(id: "s_y4", name: "Henna brows", category: .brows, priceCents: 5500, minutes: 40, detail: "Stains the skin under the brow, lasts up to two weeks.")
            ],
            work: works(seed: 67, category: .makeup, captions: ["Eid glam", "Henna brows, soft", "Bridal, gold tones", "Natural for a christening", "Winged liner", "Mehndi night look", "Threaded brows", "Matte red", "Engagement, soft pink"]),
            reviews: [
                Review(id: "r_y1", clientFirstName: "Sara", rating: 5, text: "Understood exactly what I meant by 'not too much'. Came to my in-laws' place for Eid, in and out in an hour.", date: daysAgo(12), serviceName: "Event makeup"),
                Review(id: "r_y2", clientFirstName: "Leila", rating: 4, text: "Beautiful work. She ran a bit long on the trial but the day itself was perfect.", date: daysAgo(38), serviceName: "Bridal makeup")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(10, 18)], .wednesday: [.hours(10, 18)], .friday: [.hours(8, 21)], .saturday: [.hours(7, 22)], .sunday: [.hours(8, 18)]]),
            seed: 67, completedBookings: 140, abn: "40 665 218 093", payoutsConnected: true),

        Pro(id: "pro_ivy", firstName: "Ivy", lastInitial: "T", specialties: [.nails],
            headline: "Tiny art on tiny canvases. Also plain, if you're boring.",
            bio: "Nail artist, not just nail tech. Hand-painted florals, chrome, 3D bits, or a very clean nude if that's your thing. I work fast and I don't smudge.",
            suburb: "St Kilda", latitude: -37.8676, longitude: 144.9800, travelRadiusKm: 7, travelFeeCents: 1200,
            rating: 4.8, reviewCount: 121, isVerified: true, instantBook: true, yearsExperience: 5, responseMinutes: 15, joined: daysAgo(260),
            services: [
                Service(id: "s_i1", name: "Gel + nail art", category: .nails, priceCents: 9500, minutes: 80, detail: "Gel colour with hand-painted art on as many nails as you like.", isPopular: true),
                Service(id: "s_i2", name: "Gel manicure", category: .nails, priceCents: 6500, minutes: 55, detail: "Clean and simple."),
                Service(id: "s_i3", name: "BIAB + art", category: .nails, priceCents: 11500, minutes: 90, detail: "Strength plus something to look at."),
                Service(id: "s_i4", name: "Gel toes", category: .nails, priceCents: 6000, minutes: 45, detail: "Colour on toes, no soak. Summer feet.")
            ],
            work: works(seed: 71, category: .nails, captions: ["Daisies on sheer pink", "Aura nails, peach", "Tiny cherries", "Chrome French", "Tortoiseshell tips", "3D bows", "Marble, grey", "Blooming gel, lilac", "Plain nude, sorry"]),
            reviews: [
                Review(id: "r_i1", clientFirstName: "Mia", rating: 5, text: "Painted a tiny cat on my ring finger that looks like my actual cat. Iconic.", date: daysAgo(2), serviceName: "Gel + nail art"),
                Review(id: "r_i2", clientFirstName: "Olivia", rating: 5, text: "Fast, funny, and the art is genuinely art.", date: daysAgo(17), serviceName: "BIAB + art"),
                Review(id: "r_i3", clientFirstName: "Ruth", rating: 4, text: "Lovely. Parking in St Kilda is her problem not mine but she was still on time.", date: daysAgo(35), serviceName: "Gel manicure")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(11, 20)], .tuesday: [.hours(11, 20)], .thursday: [.hours(11, 21)], .friday: [.hours(11, 21)], .saturday: [.hours(9, 19)]]),
            seed: 71, completedBookings: 380, abn: "27 550 903 118", payoutsConnected: true),

        Pro(id: "pro_grace", firstName: "Grace", lastInitial: "N", specialties: [.hair, .makeup, .theLot],
            headline: "Hair and makeup, one visit, one calm person.",
            bio: "Nine years doing both. Most of my bookings are 'I have a thing at 7'. Blow-dry and a face in ninety minutes, and I'll zip your dress on the way out.",
            suburb: "South Yarra", latitude: -37.8400, longitude: 144.9930, travelRadiusKm: 10, travelFeeCents: 1800,
            rating: 4.8, reviewCount: 104, isVerified: true, instantBook: true, yearsExperience: 9, responseMinutes: 18, joined: daysAgo(290),
            services: [
                Service(id: "s_g1", name: "Hair + makeup", category: .theLot, priceCents: 24000, minutes: 100, detail: "Blow-dry or waves, plus a full face. Ready to walk out.", isPopular: true),
                Service(id: "s_g2", name: "Blow-dry", category: .hair, priceCents: 8000, minutes: 45, detail: "Wash and blow-dry, sleek or bouncy."),
                Service(id: "s_g3", name: "Event makeup", category: .makeup, priceCents: 14000, minutes: 60, detail: "Full face with lashes."),
                Service(id: "s_g4", name: "Waves only", category: .hair, priceCents: 7000, minutes: 40, detail: "On dry hair. Soft or glam.")
            ],
            work: works(seed: 83, category: .theLot, captions: ["Waves + soft glam", "Sleek bun + red lip", "Blow-dry, big", "Half-up + bronze", "Race day", "Formal, low chignon", "Beach waves + freckles", "Ponytail + graphic liner", "Bridesmaid, rose gold"]),
            reviews: [
                Review(id: "r_g1", clientFirstName: "Isla", rating: 5, text: "Booked at 4, she was at mine by 5:15, I was out the door at 6:45 looking like someone with their life together.", date: daysAgo(5), serviceName: "Hair + makeup"),
                Review(id: "r_g2", clientFirstName: "Poppy", rating: 5, text: "Race day hair held through wind and champagne.", date: daysAgo(30), serviceName: "Waves only")
            ],
            availability: WeeklyAvailability(hours: [.tuesday: [.hours(12, 21)], .wednesday: [.hours(12, 21)], .thursday: [.hours(12, 22)], .friday: [.hours(10, 23)], .saturday: [.hours(8, 23)], .sunday: [.hours(10, 18)]]),
            seed: 83, completedBookings: 300, abn: "63 118 275 990", payoutsConnected: true),

        Pro(id: "pro_lena", firstName: "Lena", lastInitial: "K", specialties: [.lashes],
            headline: "Volume lashes, light hands, no drama.",
            bio: "Just lashes. That's it, that's the bio. Russian volume, mega volume, wet look, hybrid. I do a lot of infills at 6am for nurses and 9pm for everyone else.",
            suburb: "Carlton", latitude: -37.8000, longitude: 144.9670, travelRadiusKm: 8, travelFeeCents: 1000,
            rating: 4.6, reviewCount: 57, isVerified: false, instantBook: true, yearsExperience: 3, responseMinutes: 10, joined: daysAgo(90),
            services: [
                Service(id: "s_l1", name: "Volume set", category: .lashes, priceCents: 15000, minutes: 120, detail: "Handmade fans, 3D to 6D. Full and fluffy.", isPopular: true),
                Service(id: "s_l2", name: "Infill", category: .lashes, priceCents: 8000, minutes: 75, detail: "Within three weeks of a set. 50% or more lashes remaining."),
                Service(id: "s_l3", name: "Wet look set", category: .lashes, priceCents: 13000, minutes: 100, detail: "Spiky, glossy, very now."),
                Service(id: "s_l4", name: "Removal", category: .lashes, priceCents: 3000, minutes: 25, detail: "Gentle, cream-based. Your lashes stay yours.")
            ],
            work: works(seed: 97, category:.lashes, captions: ["Mega volume", "Wet look, spiky", "Hybrid, natural", "Volume, cat eye", "Infill, week 3", "Light volume for work", "Doll eye", "Brown lashes", "Coloured tips, blue"]),
            reviews: [
                Review(id: "r_l1", clientFirstName: "Beth", rating: 5, text: "6am infill before a night shift. She was cheerful. I was not. Lashes great.", date: daysAgo(8), serviceName: "Infill"),
                Review(id: "r_l2", clientFirstName: "Kim", rating: 4, text: "Really good set. One lash came off day two, she came back and fixed it free.", date: daysAgo(24), serviceName: "Volume set"),
                Review(id: "r_l3", clientFirstName: "Dani", rating: 4, text: "Good, quick. Would've liked a bit more explanation of the aftercare.", date: daysAgo(50), serviceName: "Wet look set")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(6, 22)], .tuesday: [.hours(6, 22)], .wednesday: [.hours(6, 22)], .thursday: [.hours(6, 22)], .friday: [.hours(6, 22)], .saturday: [.hours(8, 18)]]),
            seed: 97, completedBookings: 120, abn: "95 302 887 441", payoutsConnected: false),

        Pro(id: "pro_priya", firstName: "Priya", lastInitial: "S", specialties: [.brows, .lashes],
            headline: "Threading since I was fourteen. Brows are a craft.",
            bio: "Threading, tinting, lamination, lash lifts. My mum taught me, her mum taught her. I'm quick because I've done it ten thousand times, and I'll tell you honestly if lamination isn't for your brows.",
            suburb: "Prahran", latitude: -37.8500, longitude: 144.9920, travelRadiusKm: 8, travelFeeCents: 1000,
            rating: 4.9, reviewCount: 176, isVerified: true, instantBook: true, yearsExperience: 12, responseMinutes: 15, joined: daysAgo(380),
            services: [
                Service(id: "s_p1", name: "Brow threading", category: .brows, priceCents: 3500, minutes: 20, detail: "Clean shape, no wax, no redness by the time I've packed up.", isPopular: true),
                Service(id: "s_p2", name: "Thread + tint", category: .brows, priceCents: 5500, minutes: 35, detail: "Shape and colour, matched to your hair."),
                Service(id: "s_p3", name: "Brow lamination", category: .brows, priceCents: 8000, minutes: 50, detail: "Includes thread and tint. Six weeks of fluffy."),
                Service(id: "s_p4", name: "Lash lift + tint", category: .lashes, priceCents: 8500, minutes: 55, detail: "Curl and colour. No extensions, no upkeep."),
                Service(id: "s_p5", name: "Upper lip thread", category: .brows, priceCents: 1500, minutes: 10, detail: "Add on. Ten minutes.")
            ],
            work: works(seed: 101, category: .brows, captions: ["Threaded, natural arch", "Lamination, brushed up", "Tint, ash brown", "Lift and tint", "Before and after, thread", "Full brow rebuild", "Soft, straight brow", "Bold, dark tint", "Lift on short lashes"]),
            reviews: [
                Review(id: "r_p1", clientFirstName: "Aisha", rating: 5, text: "Twenty minutes, in my lounge room, best brows of my life. I've been going to the wrong people for a decade.", date: daysAgo(1), serviceName: "Brow threading"),
                Review(id: "r_p2", clientFirstName: "Meg", rating: 5, text: "Told me lamination would look silly on me and did a thread and tint instead. She was right. Trust her.", date: daysAgo(14), serviceName: "Thread + tint"),
                Review(id: "r_p3", clientFirstName: "Harriet", rating: 5, text: "Comes to my office every three weeks. My whole team books her now.", date: daysAgo(27), serviceName: "Brow threading")
            ],
            availability: WeeklyAvailability(hours: [.monday: [.hours(9, 19)], .tuesday: [.hours(9, 19)], .wednesday: [.hours(9, 19)], .thursday: [.hours(9, 20)], .friday: [.hours(9, 20)], .saturday: [.hours(9, 16)]]),
            seed: 101, completedBookings: 900, abn: "58 774 209 336", payoutsConnected: true)
    ]

    static func works(seed: Int, category: Category, captions: [String]) -> [WorkItem] {
        captions.enumerated().map { i, c in
            WorkItem(id: "w_\(seed)_\(i)", category: category, caption: c, seed: seed * 13 + i * 7, isPinned: i < 2, likes: (seed * (i + 3)) % 140 + 12)
        }
    }

    // MARK: The pro you are, in Pro mode

    static var proSelf: Pro { pros[0] } // Kiara

    // MARK: Bookings

    static func bookings() -> [Booking] {
        let kiara = pros[0], mei = pros[1], sofia = pros[3], ruby = pros[2], priya = pros[9]
        let home = client.addresses[0], work = client.addresses[1]
        let tonight = now.startOfDay.at(hour: 18, minute: 15)
        let saturday = nextWeekday(.saturday).at(hour: 9, minute: 0)
        let inTenDays = now.adding(days: 10).at(hour: 17, minute: 30)

        func make(_ id: String, _ pro: Pro, _ services: [Service], _ start: Date, _ address: Address, _ status: BookingStatus, notes: String = "", created: Date, review: Review? = nil, tip: Int = 0, ref: String) -> Booking {
            var price = PriceBreakdown(servicesCents: services.reduce(0) { $0 + $1.priceCents }, travelFeeCents: pro.travelFeeCents)
            price.tipCents = tip
            let events: [BookingStatus] = BookingStatus.timeline.contains(status) ? Array(BookingStatus.timeline.prefix(while: { $0 != status })) + [status] : [.requested, .confirmed, status]
            let evs = events.enumerated().map { i, s in StatusEvent(id: "\(id)_e\(i)", status: s, at: created.adding(minutes: i * 40)) }
            return Booking(id: id, proID: pro.id, clientID: clientID, services: services, start: start, address: address, notes: notes, inspoSeeds: [], status: status, price: price, createdAt: created, events: evs, review: review, paymentMethodID: "pm_apple", reference: ref)
        }

        return [
            make("bk_1", kiara, [kiara.services[0]], tonight, home, .confirmed, notes: "Milky pink please, short almond. Same as last time.", created: daysAgo(2), ref: "HD-4K2P"),
            make("bk_2", mei, [mei.services[1]], saturday, home, .requested, notes: "It's a 40th at 7, I'd like waves that last.", created: now.adding(hours: -1), ref: "HD-9RTX"),
            make("bk_3", sofia, [sofia.services[0]], inTenDays, work, .confirmed, notes: "", created: daysAgo(1), ref: "HD-2MVB"),
            make("bk_4", priya, [priya.services[1]], daysAgo(6).at(hour: 12, minute: 30), work, .paid, created: daysAgo(8), review: Review(id: "rv_me_1", clientFirstName: "Tash", rating: 5, text: "Quick, neat, and she matched the tint to my roots not my ends. Smart.", date: daysAgo(6), serviceName: "Thread + tint"), tip: 500, ref: "HD-7QLA"),
            make("bk_5", kiara, [kiara.services[1]], daysAgo(27).at(hour: 18, minute: 0), home, .paid, notes: "Cherry red.", created: daysAgo(30), review: nil, tip: 1000, ref: "HD-6HNE"),
            make("bk_6", ruby, [ruby.services[2]], daysAgo(52).at(hour: 16, minute: 0), home, .paid, created: daysAgo(55), review: Review(id: "rv_me_2", clientFirstName: "Tash", rating: 5, text: "Looked like me after a week's sleep. Booking again for the wedding.", date: daysAgo(52), serviceName: "Soft glam"), ref: "HD-3PWC"),
            make("bk_7", mei, [mei.services[0]], daysAgo(70).at(hour: 17, minute: 0), home, .cancelledByClient, created: daysAgo(74), ref: "HD-8ZKD")
        ]
    }

    /// Bookings the pro (Kiara) sees, from other clients.
    static func proBookings() -> [Booking] {
        let kiara = pros[0]
        let today = now.startOfDay
        func addr(_ id: String, _ line: String, _ suburb: String, _ pc: String, _ lat: Double, _ lon: Double) -> Address {
            Address(id: id, label: "Home", line1: line, suburb: suburb, postcode: pc, latitude: lat, longitude: lon)
        }
        func make(_ id: String, _ clientID: String, _ services: [Service], _ start: Date, _ address: Address, _ status: BookingStatus, notes: String = "", created: Date, tip: Int = 0, ref: String) -> Booking {
            var price = PriceBreakdown(servicesCents: services.reduce(0) { $0 + $1.priceCents }, travelFeeCents: kiara.travelFeeCents)
            price.tipCents = tip
            let events: [BookingStatus] = BookingStatus.timeline.contains(status) ? Array(BookingStatus.timeline.prefix(while: { $0 != status })) + [status] : [.requested, .confirmed, status]
            let evs = events.enumerated().map { i, s in StatusEvent(id: "\(id)_e\(i)", status: s, at: created.adding(minutes: i * 40)) }
            return Booking(id: id, proID: kiara.id, clientID: clientID, services: services, start: start, address: address, notes: notes, inspoSeeds: [], status: status, price: price, createdAt: created, events: evs, reference: ref)
        }
        return [
            make("pb_1", "client_priya", [kiara.services[0]], today.at(hour: 10, minute: 30), addr("a1", "3/22 Lygon St", "Brunswick East", "3057", -37.7720, 144.9720), .paid, created: daysAgo(3), tip: 1000, ref: "HD-1AAB"),
            make("pb_2", "client_georgia", [kiara.services[2]], today.at(hour: 13, minute: 0), addr("a2", "8 Albert St", "Brunswick", "3056", -37.7670, 144.9590), .done, notes: "Cherry red, coffin, medium.", created: daysAgo(2), ref: "HD-1BBC"),
            make("pb_3", "client_tash", [kiara.services[0]], today.at(hour: 18, minute: 15), client.addresses[0], .confirmed, notes: "Milky pink please, short almond. Same as last time.", created: daysAgo(2), ref: "HD-4K2P"),
            make("pb_4", "client_zoe", [kiara.services[1]], today.adding(days: 1).at(hour: 9, minute: 0), addr("a4", "41 Pigdon St", "Carlton North", "3054", -37.7850, 144.9700), .requested, notes: "Something chrome? Open to ideas.", created: now.adding(hours: -2), ref: "HD-1CCD"),
            make("pb_5", "client_hannah", [kiara.services[3]], today.adding(days: 1).at(hour: 15, minute: 30), addr("a5", "12 Barkly St", "Brunswick", "3056", -37.7660, 144.9620), .requested, created: now.adding(minutes: -25), ref: "HD-1DDE"),
            make("pb_6", "client_amira", [kiara.services[1]], today.adding(days: 3).at(hour: 11, minute: 0), addr("a6", "77 Hope St", "Brunswick West", "3055", -37.7620, 144.9450), .confirmed, notes: "For my mum, she's 78. Please be patient with her hands.", created: daysAgo(1), ref: "HD-1EEF"),
            make("pb_7", "client_lucy", [kiara.services[2]], daysAgo(1).at(hour: 14, minute: 0), addr("a7", "5 Union St", "Brunswick", "3056", -37.7690, 144.9610), .paid, created: daysAgo(4), tip: 1500, ref: "HD-1FFG"),
            make("pb_8", "client_nina", [kiara.services[1]], daysAgo(2).at(hour: 10, minute: 0), addr("a8", "19 Victoria St", "Brunswick", "3056", -37.7700, 144.9650), .paid, created: daysAgo(5), ref: "HD-1GGH"),
            make("pb_9", "client_ella", [kiara.services[0]], daysAgo(3).at(hour: 17, minute: 0), addr("a9", "2 Dawson St", "Brunswick", "3056", -37.7680, 144.9580), .paid, created: daysAgo(6), tip: 500, ref: "HD-1HHI"),
            make("pb_10", "client_jo", [kiara.services[4]], daysAgo(5).at(hour: 12, minute: 0), addr("a10", "30 Brunswick Rd", "Brunswick East", "3057", -37.7740, 144.9710), .cancelledByClient, created: daysAgo(7), ref: "HD-1IIJ")
        ]
    }

    /// First names for the pro's clients, keyed by id.
    static let clientNames: [String: String] = [
        "client_tash": "Tash", "client_priya": "Priya", "client_georgia": "Georgia", "client_zoe": "Zoe", "client_hannah": "Hannah",
        "client_amira": "Amira", "client_lucy": "Lucy", "client_nina": "Nina", "client_ella": "Ella", "client_jo": "Jo"
    ]

    // MARK: Threads

    static func threads() -> [MessageThread] {
        [
            MessageThread(id: "th_1", bookingID: "bk_1", proID: "pro_kiara", clientID: clientID, messages: [
                Message(id: "m1", threadID: "th_1", senderID: "system", text: "Confirmed for tonight at 6:15 pm.", sentAt: daysAgo(2), isSystem: true),
                Message(id: "m2", threadID: "th_1", senderID: "pro_kiara", text: "Hi Tash, see you tonight. Still milky pink? I've got a new one that's a touch warmer if you want to try it.", sentAt: now.adding(hours: -3)),
                Message(id: "m3", threadID: "th_1", senderID: clientID, text: "Ooh yes, warmer sounds good. Door's the blue one.", sentAt: now.adding(hours: -2)),
                Message(id: "m4", threadID: "th_1", senderID: "pro_kiara", text: "Perfect. I'll message when I'm five minutes out.", sentAt: now.adding(minutes: -90))
            ], unreadForClient: 1),
            MessageThread(id: "th_2", bookingID: "bk_2", proID: "pro_mei", clientID: clientID, messages: [
                Message(id: "m5", threadID: "th_2", senderID: "system", text: "You asked Mei for Saturday, 9:00 am.", sentAt: now.adding(hours: -1), isSystem: true),
                Message(id: "m6", threadID: "th_2", senderID: clientID, text: "Hi Mei, it's for a 40th. Hair's shoulder length, fine, holds a curl badly. Can we make it last till midnight?", sentAt: now.adding(minutes: -58))
            ]),
            MessageThread(id: "th_3", bookingID: "bk_4", proID: "pro_priya", clientID: clientID, messages: [
                Message(id: "m7", threadID: "th_3", senderID: "pro_priya", text: "Thanks for the tip Tash, and the review. Three weeks and they'll be ready for a tidy.", sentAt: daysAgo(6).adding(hours: 3))
            ]),
            MessageThread(id: "th_4", bookingID: "pb_4", proID: "pro_kiara", clientID: "client_zoe", messages: [
                Message(id: "m8", threadID: "th_4", senderID: "client_zoe", text: "Hi! Any chance you can do Tuesday morning instead if tomorrow doesn't work?", sentAt: now.adding(minutes: -40))
            ], unreadForPro: 1),
            MessageThread(id: "th_5", bookingID: "pb_6", proID: "pro_kiara", clientID: "client_amira", messages: [
                Message(id: "m9", threadID: "th_5", senderID: "client_amira", text: "Mum's so excited. She's picked a lilac.", sentAt: daysAgo(1)),
                Message(id: "m10", threadID: "th_5", senderID: "pro_kiara", text: "Lilac is a great call. I've got three. See you both Thursday.", sentAt: daysAgo(1).adding(hours: 2))
            ])
        ]
    }

    static func payouts() -> [Payout] {
        [
            Payout(id: "po_1", amountCents: 36960, date: now.adding(days: 1), status: .pending, bookingIDs: ["pb_1", "pb_2", "pb_7"]),
            Payout(id: "po_2", amountCents: 24120, date: daysAgo(2), status: .paid, bookingIDs: ["pb_8", "pb_9"]),
            Payout(id: "po_3", amountCents: 41800, date: daysAgo(9), status: .paid, bookingIDs: []),
            Payout(id: "po_4", amountCents: 38200, date: daysAgo(16), status: .paid, bookingIDs: []),
            Payout(id: "po_5", amountCents: 29900, date: daysAgo(23), status: .paid, bookingIDs: [])
        ]
    }

    static func nextWeekday(_ weekday: Weekday) -> Date {
        var d = now.startOfDay.adding(days: 1)
        while d.weekday != weekday { d = d.adding(days: 1) }
        return d
    }
}
