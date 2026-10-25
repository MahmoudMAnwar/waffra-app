import 'waffra_category_catalog.dart';

/// English display names for built-in categories only. Stored names, IDs,
/// deduplication keys and exported financial history remain in Arabic.
/// Each record is parent name followed by the ordered subcategory names.
const Map<String,String> _englishCatalog = {
  "construction-expense": "Construction & Finishing|Building materials|Structural works|Insulation works|Interior finishing|Exterior facades|Engineering supervision|Building inspection and handover|Concrete works|Reinforcement works|Gypsum works|Marble installation|Suspended ceilings",
  "safety-expense": "Safety & Security|Fire alarm systems|Smoke and gas detectors|Fire extinguishers|Burglar alarms|Security locks|Safes|Access control systems|Personal protective equipment|Alarm system installation|Safety system maintenance|Home safety inspection|First aid supplies",
  "sustainability-expense": "Home Sustainability & Energy|Solar panels|Energy storage batteries|Solar inverters|Energy efficiency inspection|Solar system maintenance|Energy consumption meters|Waste sorting equipment|Home recycling|Water-saving filters|Smart energy controls",
  "food": "Restaurants & Cafes|Popular restaurants|Fine dining|Fast food|Food delivery|Cafes|Drinks|Desserts|Bakeries|Buffets|Breakfast|Lunch|Dinner|Work meals|App orders|Tips|Restaurant service fees|All-you-can-eat buffet|Food trucks|Ready-to-eat home meals",
  "shopping": "Shopping|Clothing|Shoes|Bags|Perfumes|Cosmetics|Accessories|Online shopping|Household supplies|Purchased gifts|Jewelry|Watches|Stationery|Personal products|Sale purchases|Auction purchases|Storage and organization supplies|Home lighting supplies|Celebration decorations",
  "transport": "Transportation|Taxi|Uber and Careem|Public transport|Metro and buses|Parking|Road tolls|Transport tickets|School transport|Order delivery|Car rental|Work commuting|Daily transport|Shared bicycles|Shared scooters|Intercity transportation|Carpooling services",
  "bills": "Bills|Electricity|Water|Gas|Home internet|Mobile phone|Landline|Sewage|Service fees|Government bill|TV subscription|Municipal fees|Other bills|Utility reconnection fees|Shared service bills|Gas cylinder refill|Meter fees",
  "health": "Health|Hospitals|Clinics|Doctors|Pharmacy and medicine|Lab tests|Scans and tests|Dental care|Eye care and glasses|Physical therapy|Health insurance|Home care|Mental health|Medical devices|Vaccinations|Ambulance services|Therapeutic nutrition consultations|Genetic testing|Behavioral therapy sessions|Comprehensive medical screening|Day surgeries",
  "transfers": "Transfers|Transfers to people|International transfers|Local transfers|Family support|Financial assistance|Transfer fees|Payment to a person|Remittance charges|Shared contribution|Other transfers|Outgoing instant transfers|Transfer correction fees|Returned transfer fees",
  "housing": "Housing|Monthly rent|Mortgage payment|Rental deposit|Owners association fees|Furniture|Decoration|Household tools|Furnishings|Home appliances|Furniture moving|Domestic workers|Cleaning services|Home maintenance|Security and guarding|Pest control|Home swimming pool maintenance|Home water pumps|Guest room setup|Home soundproofing",
  "other": "Other|Uncategorized expense|Miscellaneous fees|Emergency needs|Settlement difference|Small expenses|Petty cash|Temporary expenses",
  "groceries": "Groceries & Provisions|Supermarket|Fruit and vegetables|Meat and poultry|Fish|Dairy and cheese|Drinking water|Kitchen supplies|Neighborhood grocery|Wholesale food|Organic products|Hospitality supplies|Household detergents|Paper supplies|Frozen foods|Nuts and spices|Gluten-free foods|Specialty plant-based foods",
  "education": "Education|School fees|University fees|Nurseries|Private lessons|Training courses|Professional certificates|Books and references|Educational stationery|Online education|School activities|School uniform|Exam fees|Paid grants|Admission and registration fees|Technology bootcamps|Research printing|Graduation projects|Scientific field trips|Internships",
  "vehicle": "Vehicle|Petrol and fuel|Electric vehicle charging|Routine maintenance|Oil change|Tires|Spare parts|Car wash|Car insurance|Vehicle inspection|Registration renewal|Traffic violations|Accident repairs|Car accessories|Car installment|Towing and transport|Roadside assistance|Vehicle plate replacement fees|Offsite EV charging fees|Pre-purchase car inspection|Vehicle safety equipment",
  "travel": "Travel & Tourism|Flight tickets|Hotels|Serviced apartments|Bookings|Visas|Passport|Luggage|Domestic tourism|International tourism|Sightseeing tours|Currency exchange|Travel insurance|Travel transport|Travel dining|Booking change fees|Booking cancellation fees|Travel SIM card|International driving permit|Airport transport",
  "personal": "Personal Care|Haircuts|Salons|Skin care|Care products|Hair care|Beauty|Spa|Massage|Laundry|Personal clothing|Dental hygiene|Daily needs|Hair removal sessions|Cosmetic contact lenses|Beard care products|Clothing tailoring and alterations",
  "family": "Family|Family expenses|Parents needs|Supporting relatives|Family visits|Family occasions|Elderly care|Family supplies|Children support|Spouse allowance|Home nanny|Family counseling sessions|Family reunification expenses|Adult children support|Family visit supplies",
  "children": "Children|Baby formula|Diapers|Children clothes|Children toys|Childcare|Nursery|Children school|Children activities|Children health|Newborn supplies|Children birthdays|School trips|Baby feeding supplies|Children learning apps|Child safety equipment|Children skill workshops",
  "entertainment": "Entertainment|Cinema|Events|Concerts and parties|Parks|Amusement parks|Video games|Electronic games|Recreational trips|Gaming cafes|Entertainment subscriptions|Weekend activities|Recreational books|Virtual reality games|Exhibition subscriptions|Theater tickets|Museum admission",
  "sport": "Sports & Fitness|Gym membership|Personal trainer|Sports equipment|Sports clothing|Sports grounds|Home exercise|Swimming|Yoga|Races|Sports supplements|Sports tournaments|Sports competition fees|Sports equipment rental|Fitness rehabilitation|Water sports sessions",
  "subscriptions": "Digital Subscriptions|Film streaming|Music streaming|Apps|Cloud services|AI subscriptions|Online games|Office software|Design software|Website memberships|Newspapers and magazines|Digital learning|Cybersecurity software|Domain registration|Website hosting|VPN subscriptions|Professional email service|Video meeting platforms",
  "gifts": "Gifts|Family gifts|Friends gifts|Occasion gifts|Wedding gifts|Children gifts|Gift wrapping|Gift cards|Work gifts|Holiday gifts|Digital gift vouchers|Gift delivery fees|Hospitality gifts",
  "sadaqat": "Voluntary Charity|Daily charity|Friday charity|Ongoing charity|Charity for parents|Ramadan iftar charity|Drinking water charity|Orphans charity|Private charity|Other charity|Online platform charity|Emergency charity|Animal feeding charity",
  "charity": "Donations & Assistance|Charity organization donation|Charity campaign donation|Support for orphans|Family sponsorship|Medical donation|Educational donation|Humanitarian relief|Food donation|Community project donation|Helping someone in need|Public facilities fundraising|Environmental initiative donations|Blood donation drive support",
  "zakat": "Zakat & Expiation|Wealth zakat|Zakat al-Fitr|Gold zakat|Trade zakat|Oath expiation|Fasting expiation|Fidya|Vows|Other expiations|Vow expiation|Family Zakat al-Fitr|Crop Zakat",
  "religious": "Worship & Religious Occasions|Umrah|Hajj|Sacrificial offerings|Aqiqah|Ramadan iftar|Eid gifts|Eid preparations|Religious books|Religious trips|Mosque expenses|I'tikaf expenses|Ihram supplies|Religious site visits",
  "pets": "Pets|Pet food|Veterinary treatment|Vaccinations|Pet supplies|Pet grooming|Pet boarding|Pet purchase|Pet training|Pet insurance|Pet walking services|Pet travel documents|Aquarium supplies|Pet daycare",
  "insurance": "Insurance|Additional health insurance|Car insurance|Home insurance|Life insurance|Travel insurance|Business insurance|Property insurance|Insurance premiums|Policy fees|Civil liability insurance|Insurance claim fees|Electronics insurance|Domestic worker insurance",
  "business": "Business Expenses|Office rent|Employee salaries|Work equipment|Inventory and goods|Marketing and advertising|Goods shipping|Commercial transport|Business software|Accountant fees|Legal services|Commercial subscriptions|Business permits|Equipment maintenance|Work petty cash|Payment gateway fees|Ecommerce platform fees|Commercial packaging materials|Point-of-sale subscriptions|Influencer marketing campaigns|Trademark registration fees",
  "government": "Government Fees|ID fees|Residence permit fees|Passport fees|Visa fees|License fees|Municipal fees|Commercial register fees|Court fees|Transaction fees|Other government fees|National address renewal fees|Government document delivery|Late renewal penalties|Government online platform fees",
  "debts": "Debts & Commitments|Personal loan repayment|Financing repayment|Credit card installment|Financing fees|Debt to relatives|Debt repayment|Purchase installments|Late payment penalty|Other dues|Loan rescheduling fees|Debt collection fees|Debt statement fees",
  "wedding": "Weddings & Occasions|Dowry|Wedding hall|Event photography|Event catering|Occasion clothing|Wedding jewelry|Party planning|Invitations|Occasion gifts|Honeymoon travel|Premarital medical screening|Event lighting arrangement|Marriage contract notarization fees",
  "maintenance": "Maintenance & Repairs|Home electricity work|Plumbing|Air conditioning|Painting|Renovation|Carpentry|Appliance maintenance|Elevator maintenance|Furniture repair|Repair tools|Fire protection system maintenance|Water leak inspection|Automatic door maintenance|Electric generator maintenance",
  "electronics": "Electronics & Technology|Mobile phones|Computers|Tablets|Electronic accessories|Phone repair|Computer maintenance|Home networks|Cameras|Smart devices|Software and hardware|Gaming accessories|Advanced home networking devices|External storage units|Portable device batteries|Smart device repair fees",
  "professional": "Professional Expenses|Professional memberships|Certificate renewals|Professional licensing fees|Conferences|Business travel|Specialist books|Professional tools|Employee training|Work clothes|Recruitment platform subscriptions|Skill assessment fees|Career fair setup",
  "hobbies": "Hobbies & Interests|Drawing and arts|Photography|Music|Reading|Handicrafts|Home gardening|Camping|Fishing|Collectibles|Hobby projects|Musical instrument lessons|3D modeling and printing|Astronomy observation|Candle-making supplies",
  "taxes": "Taxes & Fees|Value-added tax|Income tax|Customs fees|Business zakat|Bank fees|Purchase commissions|Brokerage fees|Fines and fees|Tax appeal fees|Tax return preparation services|Tax notarization fees",
  "childcare-extra": "Family & Dependent Care|Disability care|Rehabilitation sessions|Patient companion|Domestic help|Assistive devices|Medical transport|Care supplies|Mobility aids|Caregiver support services|Home rehabilitation",
  "farm-expense": "Farming & Gardens|Seeds and seedlings|Fertilizers|Gardening tools|Irrigation and water|Garden maintenance|Houseplants|Farm supplies|Livestock care|Feed|Smart irrigation systems|Home beekeeping|Agricultural pest control|Small greenhouses|Soil testing",
  "events-expense": "Social Events|Condolences|Banquet|Hosted gathering|Graduation|Newborn celebration|Birthday|Receiving guests|Hospitality|Event preparations|Event reception services|Table and chair rental|Event decorations",
  "legal-expense": "Legal & Administrative Services|Legal advice|Lawyer fees|Contract notarization|Certified translation|Document attestation|Administrative follow-up|Lawsuit fees|Registration fees|Mediation and settlement fees|Legal copies and extracts|Private arbitration",
  "financial-expense": "Financial Services|Account fees|Card fees|Transfer fees|ATM commission|Withdrawal fees|Currency conversion fees|Investment fees|Financial advisory fees|Digital wallet fees|International payment fees|Card replacement fees|Instant transfer fees|Account statement fees",
  "emergency-expense": "Emergencies & Unexpected Expenses|Emergency treatment|Urgent repairs|Urgent assistance|Device replacement|Property damage|Emergency transport|Unexpected expenses|Emergency transportation|Emergency temporary accommodation|Evacuation supplies|Home emergency equipment",
  "online-income": "Digital & Technology Income|App sales|Digital subscriptions|Template sales|Design sales|Software licensing|Digital products|Technical services|Website development",
  "commission-income": "Commissions & Brokerage|Real estate commission|Marketing commission|Referral commission|Trade brokerage|Sales commission|Brokerage|Service commission",
  "prizes-income": "Prizes & Rewards|Competition prize|Achievement bonus|Cash prize|Volunteer reward|Performance incentive|Loyalty reward",
  "insurance-income": "Compensation & Entitlements|Accident compensation|Damage compensation|Medical compensation|Court-awarded dues|Work compensation|Insurance entitlements|Travel compensation",
  "royalties-income": "Royalties & Intellectual Property|Publishing rights|Copyright royalties|Image licensing|Music licensing|Product royalties|Patent rights|Trademark licensing",
  "services-income": "Household & Personal Services|Home maintenance|Cleaning|Childcare|Elderly care|Event planning|Delivery services|Personal training|Private lessons",
  "salary": "Salary|Base salary|Housing allowance|Transport allowance|Communication allowance|Work nature allowance|Overtime in salary|Performance bonus|Annual raise|Back pay|Leave compensation|Part-time salary|End-of-service award|Business trip allowance|Shift allowance|Hazard allowance|Team leadership allowance",
  "extra": "Additional Work|Overtime|Seasonal work|Extra shift|Assignment compensation|Additional commission|Bonus outside salary|Hourly work|Weekend income|On-call hours compensation|Temporary assignment compensation|Additional shift income",
  "other-income": "Other Income|Uncategorized income|Unexpected gift|Refunded amount|Financial settlement|Other compensation|Miscellaneous income|Other bonus|Service delay compensation|Personal cash incentive|One-time income",
  "freelance-income": "Freelance Work|Design|Programming|Translation|Content writing|Freelance marketing|Consulting|Photography|Video editing|Private tutoring|Home services|Professional services|Project-based work|Social media management|Paid voiceover|Proofreading",
  "commerce-income": "Trade & Sales|Store sales|Online sales|Reselling|Wholesale sales|Retail sales|Seasonal sales|Sales commission|Digital product sales|Handmade product sales|Selling personal items|Subscription product sales|Auction sales|Secondhand product sales",
  "investment-income": "Investment Returns|Stock dividends|Fund distributions|Sukuk returns|Murabaha returns|Stock sale gains|Fund gains|Partnership profits|Investment redemption|Other profits|Savings certificate returns|Crowdfunded real estate returns|Private debt instrument returns",
  "rental-income": "Real Estate Income|Apartment rent|House rent|Shop rent|Office rent|Land rent|Warehouse rent|Room rentals|Seasonal rent|Property management return|Parking space rentals|Property advertising billboard rental|Property facility usage fees",
  "business-income": "Business Income|Business profits|Service revenue|Customer subscriptions|Store revenue|Contracting revenue|Restaurant revenue|Delivery revenue|Franchise income|Project commission|Reservation fee revenue|Equipment usage revenue|Service contract revenue",
  "gifts-income": "Received Gifts & Support|Cash gift|Eid gift money|Family assistance|Relative support|Received donation|Friends support|Emergency assistance|Gift|Personal grant from a friend|Cash wedding gift|Private organization support",
  "refunds-income": "Refunds|Purchase refund|Bill refund|Subscription refund|Insurance compensation|Fee refund|Tax refund|Work expense reimbursement|Deposit refund|Booking refund|Ticket booking fee refunds|Overpayment refunds|Bank fee refunds",
  "government-income": "Government Support & Benefits|Citizen Account|Social security|Housing subsidy|Rural support|Government assistance|Student bonus|Training subsidy|Official compensation|Additional support|Work equipment support|Entrepreneurship grants|Energy efficiency subsidies",
  "incoming-transfers": "Incoming Transfers|Family remittance|Transfer from a friend|International remittance|Local remittance|Settlement between people|Transfer received in error|Other received transfer|Transfer from employer|International transfer from relative|Personal compensation transfer",
  "pension-income": "Pensions & Entitlements|Retirement pension|Social insurance pension|Survivor pension|Unemployment compensation|End-of-service compensation|Monthly allowance|Government dues|Previous entitlements|Pension difference payment|Retirement lump sum|Employment guarantee entitlement",
  "agriculture-income": "Agriculture & Livestock Income|Crop sales|Livestock sales|Honey production|Dairy production|Poultry sales|Date sales|Agricultural production|Farm products|Organic farm produce sales|Seedling sales|Animal feed sales|Beekeeping service income",
  "creator-income": "Content Creation|Content advertising|Sponsored content|Live-stream income|Course sales|Digital book sales|Marketing commissions|Channel revenue|Audience support|Newsletter sales|Content community memberships|Paid newsletter income",
  "selling-assets-income": "Asset & Property Sales|Car sale|Property sale|Furniture sale|Gold sale|Device sale|Land sale|Selling personal items|Equipment sale|Sports equipment sales|Used household item sales|Professional equipment sales",
  "home-office-expense": "Working from Home|Home office setup|Office chair|Work desk|Office lighting|Printing supplies|Work connectivity services|Soundproofing|Backup internet for work|Video meeting backdrop soundproofing|Home meeting equipment",
  "public-services-expense": "Public Services|Postal fees|Document shipping|Copying and printing|General translation services|Non-government attestation services|Community service fees|Post office box rental|Paper records archiving|3D printing services",
  "property-expense": "Property Management|Real estate transaction tax|Property valuation|Property management commission|Property listing|Rental notarization fees|Rental property maintenance|Rental property setup|Pre-rental property cleaning|Property photography and marketing|Pre-handover property inspection",
  "caregiving-expense": "Long-term Healthcare|Home nursing|Dialysis sessions|Elderly supplies|Breathing equipment|Occupational therapy|Speech therapy|Chronic illness monitoring|End-of-life care|Mobile home treatment|Patient monitoring systems",
  "moving-expense": "Moving & New Home|Housing deposit|Moving belongings|Furniture storage|Curtain installation|Appliance installation|New home setup|Housing contract fees|Meter transfer fees|Furniture dismantling and reassembly|Moving goods insurance",
  "education-income": "Education & Training Income|Paid private tutoring|Educational material sales|Paid training workshops|Exam preparation|Curriculum writing|Corporate training|Paid exam marking|Professional mentoring sessions|Remote team training",
  "transport-income": "Transport & Delivery Income|Ride-hailing driving|Parcel delivery|Food delivery|Vehicle rental|Goods transport|Private transport services|EV charging revenue|Personal shopping delivery|Travel companion fees",
  "equipment-rental-income": "Equipment & Property Rental|Camera equipment rental|Tool rental|Party equipment rental|Device rental|Construction equipment rental|Storage space rental|Sports equipment rental|Audio equipment rental|Hourly workspace rental",
  "seasonal-income": "Seasonal Income|Hajj season work|Umrah season work|Ramadan trade|Eid sales|Seasonal exhibitions|Holiday work|Ramadan supply sales|Seasonal tour guiding|Seasonal event organizing",
  "scholarship-income": "Scholarships & Study Allowances|Scholarship|Academic excellence award|Research allowance|Study abroad allowance|Graduation project funding|Cooperative training bonus|Academic publication award|Scientific conference support|Education supply grants",
  "recovery-income": "Debt & Receivable Collection|Personal loan repayment received|Old debt collection|Trade receivables collected|Payment due from someone|Advance repayment received|Overdue rent collection|Overdue project payment collection|Court-ordered recovery",
  "inheritance-income": "Inheritance & Wills|Cash inheritance share|Cash bequest|Estate distribution|Estate entitlements|Estate account proceeds|Estate liquidation returns|Will share value",
  "licensing-income": "Licensing Income|Design license|Content license|Technology license|Product license|Intellectual property relicensing|Audio file licensing|Patent licensing|Training material licensing",
  "farm-rental-income": "Farmland Rental|Farm rent|Agricultural land rent|Greenhouse rent|Agricultural equipment rent|Plant nursery rental|Agricultural warehouse rental|Livestock barn rental",
};

final Map<String,String> _waffraEnglishByArabic = _buildEnglishByArabic();

Map<String,String> _buildEnglishByArabic() {
 final result=<String,String>{};
 for(final group in waffraCategoryCatalog){
  final row=_englishCatalog[group.id];
  if(row==null)throw StateError('Missing English group translation: ${group.id}');
  final labels=row.split('|');
  if(labels.length!=group.subcategories.length+1){
   throw StateError('Incorrect English subcategory count for ${group.id}');
  }
  for(var i=0;i<group.subcategories.length;i++){
   final sub=group.subcategories[i];
   // Duplicate child labels may occur under different parents.
   result.putIfAbsent(sub,()=>labels[i+1]);
   result['${group.name} / $sub']='${labels.first} / ${labels[i+1]}';
  }
 }
 // Main category labels outrank identically spelled subcategories.
 for(final group in waffraCategoryCatalog){
  result[group.name]=_englishCatalog[group.id]!.split('|').first;
 }
 return Map<String,String>.unmodifiable(result);
}

/// Translate only official catalog labels. Preserve all stored names/IDs.
String waffraEnglishCategoryLabel(String value) =>
 _waffraEnglishByArabic[value]??value;
/// Exposed for exhaustive catalog coverage regressions.
bool get waffraEnglishCategoryCatalogComplete =>
 _englishCatalog.length==waffraCategoryCatalog.length &&
 waffraCategoryCatalog.every((group)=>
  _englishCatalog[group.id]!.split('|').length==group.subcategories.length+1);
