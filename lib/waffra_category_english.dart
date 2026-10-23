import 'waffra_category_catalog.dart';

/// English display names for built-in categories only. Stored names, IDs,
/// deduplication keys and exported financial history remain in Arabic.
/// Each record is parent name followed by the ordered subcategory names.
const Map<String,String> _englishCatalog = {
  "food": "Restaurants & Cafes|Local restaurants|Fine dining|Fast food|Food delivery|Cafes|Drinks|Desserts|Bakeries|Buffets|Breakfast|Lunch|Dinner|Work meals|App orders|Tips",
  "shopping": "Shopping|Clothing|Shoes|Bags|Perfumes|Cosmetics|Accessories|Online shopping|Household supplies|Purchased gifts|Jewelry|Watches|Stationery|Personal products|Sale purchases",
  "transport": "Transportation|Taxi|Uber and Careem|Public transport|Metro and buses|Parking|Road tolls|Transport tickets|School transport|Order delivery|Car rental|Work commuting|Daily transport",
  "bills": "Bills|Electricity|Water|Gas|Home internet|Mobile phone|Landline|Sewage|Service fees|Government bill|TV subscription|Municipal fees|Other bills",
  "health": "Health|Hospitals|Clinics|Doctors|Pharmacy and medicine|Lab tests|Scans and tests|Dental care|Eye care and glasses|Physical therapy|Health insurance|Home care|Mental health|Medical devices|Vaccinations",
  "transfers": "Transfers|Transfers to people|International transfers|Local transfers|Family support|Financial assistance|Transfer fees|Payment to a person|Remittance charges|Shared contribution|Other transfers",
  "housing": "Housing|Monthly rent|Mortgage payment|Rental deposit|Owners association fees|Furniture|Decoration|Household tools|Furnishings|Home appliances|Furniture moving|Domestic workers|Cleaning services|Home maintenance|Security and guarding|Pest control",
  "other": "Other|Uncategorized expense|Miscellaneous fees|Emergency needs|Settlement difference|Small expenses|Petty cash|Temporary expenses",
  "groceries": "Groceries & Provisions|Supermarket|Fruit and vegetables|Meat and poultry|Fish|Dairy and cheese|Drinking water|Kitchen supplies|Neighborhood grocery|Wholesale food|Organic products|Hospitality supplies",
  "education": "Education|School fees|University fees|Nurseries|Private lessons|Training courses|Professional certificates|Books and references|Educational stationery|Online education|School activities|School uniform|Exam fees|Paid grants",
  "vehicle": "Vehicle|Petrol and fuel|Electric vehicle charging|Routine maintenance|Oil change|Tires|Spare parts|Car wash|Car insurance|Vehicle inspection|Registration renewal|Traffic violations|Accident repairs|Car accessories|Car installment|Towing and transport",
  "travel": "Travel & Tourism|Flight tickets|Hotels|Serviced apartments|Bookings|Visas|Passport|Luggage|Domestic tourism|International tourism|Sightseeing tours|Currency exchange|Travel insurance|Travel transport|Travel dining",
  "personal": "Personal Care|Haircuts|Salons|Skin care|Care products|Hair care|Beauty|Spa|Massage|Laundry|Personal clothing|Dental hygiene|Daily needs",
  "family": "Family|Family expenses|Parents needs|Supporting relatives|Family visits|Family occasions|Elderly care|Family supplies|Children support|Spouse allowance|Home nanny",
  "children": "Children|Baby formula|Diapers|Children clothes|Children toys|Childcare|Nursery|Children school|Children activities|Children health|Newborn supplies|Children birthdays|School trips",
  "entertainment": "Entertainment|Cinema|Events|Concerts and parties|Parks|Amusement parks|Video games|Electronic games|Recreational trips|Gaming cafes|Entertainment subscriptions|Weekend activities|Recreational books",
  "sport": "Sports & Fitness|Gym membership|Personal trainer|Sports equipment|Sports clothing|Sports grounds|Home exercise|Swimming|Yoga|Races|Sports supplements|Sports tournaments",
  "subscriptions": "Digital Subscriptions|Film streaming|Music streaming|Apps|Cloud services|AI subscriptions|Online games|Office software|Design software|Website memberships|Newspapers and magazines|Digital learning|Cybersecurity software",
  "gifts": "Gifts|Family gifts|Friends gifts|Occasion gifts|Wedding gifts|Children gifts|Gift wrapping|Gift cards|Work gifts|Holiday gifts",
  "sadaqat": "Voluntary Charity|Daily charity|Friday charity|Ongoing charity|Charity for parents|Ramadan iftar charity|Drinking water charity|Orphans charity|Private charity|Other charity",
  "charity": "Donations & Assistance|Charity organization donation|Charity campaign donation|Support for orphans|Family sponsorship|Medical donation|Educational donation|Humanitarian relief|Food donation|Community project donation|Helping someone in need",
  "zakat": "Zakat & Expiation|Wealth zakat|Zakat al-Fitr|Gold zakat|Trade zakat|Oath expiation|Fasting expiation|Fidya|Vows|Other expiations",
  "religious": "Worship & Religious Occasions|Umrah|Hajj|Sacrificial offerings|Aqiqah|Ramadan iftar|Eid gifts|Eid preparations|Religious books|Religious trips|Mosque expenses",
  "pets": "Pets|Pet food|Veterinary treatment|Vaccinations|Pet supplies|Pet grooming|Pet boarding|Pet purchase|Pet training|Pet insurance",
  "insurance": "Insurance|Additional health insurance|Car insurance|Home insurance|Life insurance|Travel insurance|Business insurance|Property insurance|Insurance premiums|Policy fees",
  "business": "Business Expenses|Office rent|Employee salaries|Work equipment|Inventory and goods|Marketing and advertising|Goods shipping|Commercial transport|Business software|Accountant fees|Legal services|Commercial subscriptions|Business permits|Equipment maintenance|Work petty cash",
  "government": "Government Fees|ID fees|Residence permit fees|Passport fees|Visa fees|License fees|Municipal fees|Commercial register fees|Court fees|Transaction fees|Other government fees",
  "debts": "Debts & Commitments|Personal loan repayment|Financing repayment|Credit card installment|Financing fees|Debt to relatives|Debt repayment|Purchase installments|Late payment penalty|Other dues",
  "wedding": "Weddings & Occasions|Dowry|Wedding hall|Event photography|Event catering|Occasion clothing|Wedding jewelry|Party planning|Invitations|Occasion gifts|Honeymoon travel",
  "maintenance": "Maintenance & Repairs|Home electricity work|Plumbing|Air conditioning|Painting|Renovation|Carpentry|Appliance maintenance|Elevator maintenance|Furniture repair|Repair tools",
  "electronics": "Electronics & Technology|Mobile phones|Computers|Tablets|Electronic accessories|Phone repair|Computer maintenance|Home networks|Cameras|Smart devices|Software and hardware",
  "professional": "Professional Expenses|Professional memberships|Certificate renewals|Professional licensing fees|Conferences|Business travel|Specialist books|Professional tools|Employee training|Work clothes",
  "hobbies": "Hobbies & Interests|Drawing and arts|Photography|Music|Reading|Handicrafts|Home gardening|Camping|Fishing|Collectibles|Hobby projects",
  "taxes": "Taxes & Fees|Value-added tax|Income tax|Customs fees|Business zakat|Bank fees|Purchase commissions|Brokerage fees|Fines and fees",
  "childcare-extra": "Family & Dependent Care|Disability care|Rehabilitation sessions|Patient companion|Domestic help|Assistive devices|Medical transport|Care supplies",
  "farm-expense": "Farming & Gardens|Seeds and seedlings|Fertilizers|Gardening tools|Irrigation and water|Garden maintenance|Houseplants|Farm supplies|Livestock care|Feed",
  "events-expense": "Social Events|Condolences|Banquet|Hosted gathering|Graduation|Newborn celebration|Birthday|Receiving guests|Hospitality|Event preparations",
  "legal-expense": "Legal & Administrative Services|Legal advice|Lawyer fees|Contract notarization|Certified translation|Document attestation|Administrative follow-up|Lawsuit fees|Registration fees",
  "financial-expense": "Financial Services|Account fees|Card fees|Transfer fees|ATM commission|Withdrawal fees|Currency conversion fees|Investment fees|Financial advisory fees",
  "emergency-expense": "Emergencies & Unexpected Expenses|Emergency treatment|Urgent repairs|Urgent assistance|Device replacement|Property damage|Emergency transport|Unexpected expenses",
  "online-income": "Digital & Technology Income|App sales|Digital subscriptions|Template sales|Design sales|Software licensing|Digital products|Technical services|Website development",
  "commission-income": "Commissions & Brokerage|Real estate commission|Marketing commission|Referral commission|Trade brokerage|Sales commission|Brokerage|Service commission",
  "prizes-income": "Prizes & Rewards|Competition prize|Achievement bonus|Cash prize|Volunteer reward|Performance incentive|Loyalty reward",
  "insurance-income": "Compensation & Entitlements|Accident compensation|Damage compensation|Medical compensation|Court-awarded dues|Work compensation|Insurance entitlements|Travel compensation",
  "royalties-income": "Royalties & Intellectual Property|Publishing rights|Copyright royalties|Image licensing|Music licensing|Product royalties|Patent rights|Trademark licensing",
  "services-income": "Household & Personal Services|Home maintenance|Cleaning|Childcare|Elderly care|Event planning|Delivery services|Personal training|Private lessons",
  "salary": "Salary|Base salary|Housing allowance|Transport allowance|Communication allowance|Work nature allowance|Overtime in salary|Performance bonus|Annual raise|Back pay|Leave compensation|Part-time salary|End-of-service award",
  "extra": "Additional Work|Overtime|Seasonal work|Extra shift|Assignment compensation|Additional commission|Bonus outside salary|Hourly work|Weekend income",
  "other-income": "Other Income|Uncategorized income|Unexpected gift|Refunded amount|Financial settlement|Other compensation|Miscellaneous income|Other bonus",
  "freelance-income": "Freelance Work|Design|Programming|Translation|Content writing|Freelance marketing|Consulting|Photography|Video editing|Private tutoring|Home services|Professional services|Project-based work",
  "commerce-income": "Trade & Sales|Store sales|Online sales|Reselling|Wholesale sales|Retail sales|Seasonal sales|Sales commission|Digital product sales|Handmade product sales|Selling personal items",
  "investment-income": "Investment Returns|Stock dividends|Fund distributions|Sukuk returns|Murabaha returns|Stock sale gains|Fund gains|Partnership profits|Investment redemption|Other profits",
  "rental-income": "Real Estate Income|Apartment rent|House rent|Shop rent|Office rent|Land rent|Warehouse rent|Room rentals|Seasonal rent|Property management return",
  "business-income": "Business Income|Business profits|Service revenue|Customer subscriptions|Store revenue|Contracting revenue|Restaurant revenue|Delivery revenue|Franchise income|Project commission",
  "gifts-income": "Received Gifts & Support|Cash gift|Eid gift money|Family assistance|Relative support|Received donation|Friends support|Emergency assistance|Gift",
  "refunds-income": "Refunds|Purchase refund|Bill refund|Subscription refund|Insurance compensation|Fee refund|Tax refund|Work expense reimbursement|Deposit refund|Booking refund",
  "government-income": "Government Support & Benefits|Citizen Account|Social security|Housing subsidy|Rural support|Government assistance|Student bonus|Training subsidy|Official compensation|Additional support",
  "incoming-transfers": "Incoming Transfers|Family remittance|Transfer from a friend|International remittance|Local remittance|Settlement between people|Transfer received in error|Other received transfer",
  "pension-income": "Pensions & Entitlements|Retirement pension|Social insurance pension|Survivor pension|Unemployment compensation|End-of-service compensation|Monthly allowance|Government dues|Previous entitlements",
  "agriculture-income": "Agriculture & Livestock Income|Crop sales|Livestock sales|Honey production|Dairy production|Poultry sales|Date sales|Agricultural production|Farm products",
  "creator-income": "Content Creation|Content advertising|Sponsored content|Live-stream income|Course sales|Digital book sales|Marketing commissions|Channel revenue|Audience support",
  "selling-assets-income": "Asset & Property Sales|Car sale|Property sale|Furniture sale|Gold sale|Device sale|Land sale|Selling personal items|Equipment sale",
  "home-office-expense": "Working from Home|Home office setup|Office chair|Work desk|Office lighting|Printing supplies|Work connectivity services|Soundproofing",
  "public-services-expense": "Public Services|Postal fees|Document shipping|Copying and printing|General translation services|Non-government attestation services|Community service fees",
  "property-expense": "Property Management|Real estate transaction tax|Property valuation|Property management commission|Property listing|Rental notarization fees|Rental property maintenance|Rental property setup",
  "caregiving-expense": "Long-term Healthcare|Home nursing|Dialysis sessions|Elderly supplies|Breathing equipment|Occupational therapy|Speech therapy|Chronic illness monitoring",
  "moving-expense": "Moving & New Home|Housing deposit|Moving belongings|Furniture storage|Curtain installation|Appliance installation|New home setup|Housing contract fees",
  "education-income": "Education & Training Income|Paid private tutoring|Educational material sales|Paid training workshops|Exam preparation|Curriculum writing|Corporate training",
  "transport-income": "Transport & Delivery Income|Ride-hailing driving|Parcel delivery|Food delivery|Vehicle rental|Goods transport|Private transport services",
  "equipment-rental-income": "Equipment & Property Rental|Camera equipment rental|Tool rental|Party equipment rental|Device rental|Construction equipment rental|Storage space rental",
  "seasonal-income": "Seasonal Income|Hajj season work|Umrah season work|Ramadan trade|Eid sales|Seasonal exhibitions|Holiday work",
  "scholarship-income": "Scholarships & Study Allowances|Scholarship|Academic excellence award|Research allowance|Study abroad allowance|Graduation project funding|Cooperative training bonus",
  "recovery-income": "Debt & Receivable Collection|Personal loan repayment received|Old debt collection|Trade receivables collected|Payment due from someone|Advance repayment received",
  "inheritance-income": "Inheritance & Wills|Cash inheritance share|Cash bequest|Estate distribution|Estate entitlements",
  "licensing-income": "Licensing Income|Design license|Content license|Technology license|Product license|Intellectual property relicensing",
  "farm-rental-income": "Farmland Rental|Farm rent|Agricultural land rent|Greenhouse rent|Agricultural equipment rent",
};

final Map<String,String> _waffraEnglishByArabic = _buildEnglishByArabic();

Map<String,String> _buildEnglishByArabic() {
 final result=<String,String>{};
 for(final group in waffraCategoryCatalog){
  final row=_englishCatalog[group.id];
  if(row==null)throw StateError('Missing English group translation: ${group.id}');
  final words=row.split('|');
  if(words.length!=group.subcategories.length+1){
   throw StateError('Incorrect English subcategory count for ${group.id}');
  }
  result[group.name]=words.first;
  for(var i=0;i<group.subcategories.length;i++){
   result[group.subcategories[i]]=words[i+1];
  }
 }
 return Map<String,String>.unmodifiable(result);
}

/// Translate catalog labels only for display. User-created category titles
/// remain exactly as entered; NEVER rewrite transactions or saved categories.
String waffraEnglishCategoryLabel(String value) {
 final exact=_waffraEnglishByArabic[value];
 if(exact!=null)return exact;
 final separator=value.indexOf(' / ');
 if(separator<0)return value;
 final main=value.substring(0,separator);
 final sub=value.substring(separator+3);
 final mainEn=_waffraEnglishByArabic[main];
 final subEn=_waffraEnglishByArabic[sub];
 if(mainEn==null||subEn==null)return value;
 return '$'+'{mainEn} / '+'$'+'{subEn}';
}

/// Exposed for exhaustive catalog coverage regressions.
bool get waffraEnglishCategoryCatalogComplete =>
 _englishCatalog.length==waffraCategoryCatalog.length &&
 waffraCategoryCatalog.every((group)=>
  _englishCatalog[group.id]!.split('|').length==group.subcategories.length+1);
