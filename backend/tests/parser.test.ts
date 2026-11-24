import assert from 'assert';
import { CardParserService } from '../src/services/cardParserService';
import { VcfService } from '../src/services/vcfService';

console.log('--- RUNNING TYPESCRIPT BUSINESS CARD PARSER TESTS ---');

// Test 1: Full Corporate Card
const sampleCard1 = `
TECHCORP INNOVATIONS PVT. LTD.
Rajesh Kumar Sharma
Managing Director
Mob: +91 98765 43210, +91 98765 43211
Email: rajesh.sharma@techcorp.in
Website: www.techcorp.in
GSTIN: 27ABCDE1234F1Z5
Office: 402, Signature Tower, S.G. Highway
Ahmedabad, Gujarat - 380054, India
`;

const result1 = CardParserService.parseBusinessCardText(sampleCard1);
console.log('Result 1 (Corporate Card):', JSON.stringify(result1, null, 2));

assert.strictEqual(result1.personName, 'Rajesh Kumar Sharma', 'Name should be Rajesh Kumar Sharma');
assert.strictEqual(result1.companyName, 'TECHCORP INNOVATIONS PVT. LTD.', 'Company should match');
assert.strictEqual(result1.designation, 'Managing Director', 'Designation should be Managing Director');
assert.strictEqual(result1.email, 'rajesh.sharma@techcorp.in', 'Email should match');
assert.strictEqual(result1.website, 'https://www.techcorp.in', 'Website should match');
assert.strictEqual(result1.phone, '+919876543210', 'Primary phone should match');
assert.strictEqual(result1.alternativePhone, '+919876543211', 'Alternative phone should match');
assert.strictEqual(result1.gstNumber, '27ABCDE1234F1Z5', 'GSTIN should match');
assert.strictEqual(result1.city, 'Ahmedabad', 'City should be Ahmedabad');
assert.strictEqual(result1.state, 'Gujarat', 'State should be Gujarat');

console.log('✓ Test 1: Full corporate card extraction passed.');

// Test 2: Medical / Consulting Card
const sampleCard2 = `
Dr. Priya Patel
Senior Consultant
Apex Healthcare Solutions
Cell: 9822012345
drpriya@apexhealth.org
Bengaluru, Karnataka
`;

const result2 = CardParserService.parseBusinessCardText(sampleCard2);
console.log('Result 2 (Doctor / Medical):', JSON.stringify(result2, null, 2));

assert.strictEqual(result2.personName, 'Dr. Priya Patel', 'Name should be Dr. Priya Patel');
assert.strictEqual(result2.designation, 'Senior Consultant', 'Designation should be Senior Consultant');
assert.strictEqual(result2.companyName, 'Apex Healthcare Solutions', 'Company should match');
assert.strictEqual(result2.phone, '9822012345', 'Phone should match');
assert.strictEqual(result2.email, 'drpriya@apexhealth.org', 'Email should match');
assert.strictEqual(result2.city, 'Bengaluru', 'City should be Bengaluru');
assert.strictEqual(result2.state, 'Karnataka', 'State should be Karnataka');

console.log('✓ Test 2: Medical / consulting card passed.');

// Test 3: Personal Business Card with Upper Case Name and Slash-separated Mobile
const sampleCard3 = `
DHRUMIL PATEL
Proprietor
SHREEJI ENTERPRISE
Mo. 9726152534 / 9825012345
pateldhrumil987@gmail.com
Shop No. 12, Radhe Complex, Near Highway
Ahmedabad, Gujarat - 380054
`;

const result3 = CardParserService.parseBusinessCardText(sampleCard3);
console.log('Result 3 (Trader / Proprietor Card):', JSON.stringify(result3, null, 2));

assert.strictEqual(result3.personName, 'DHRUMIL PATEL', 'Person name must be DHRUMIL PATEL');
assert.strictEqual(result3.designation, 'Proprietor', 'Designation must be Proprietor');
assert.strictEqual(result3.companyName, 'SHREEJI ENTERPRISE', 'Company must be SHREEJI ENTERPRISE');
assert.strictEqual(result3.phone, '9726152534', 'Primary phone must be 9726152534');
assert.strictEqual(result3.alternativePhone, '9825012345', 'Alt phone must be 9825012345');
assert.strictEqual(result3.email, 'pateldhrumil987@gmail.com', 'Email must match');

console.log('✓ Test 3: Upper-case name and trader card disambiguation passed.');

// Test 4: VCard Generation
const vcf = VcfService.generateVCard(result1);
assert.ok(vcf.includes('BEGIN:VCARD'), 'Should have BEGIN:VCARD');
assert.ok(vcf.includes('FN:Rajesh Kumar Sharma'), 'Should contain FN');
assert.ok(vcf.includes('ORG:TECHCORP INNOVATIONS PVT. LTD.'), 'Should contain ORG');
assert.ok(vcf.includes('TEL;TYPE=CELL,VOICE:+919876543210'), 'Should contain TEL');
assert.ok(vcf.includes('END:VCARD'), 'Should have END:VCARD');

console.log('✓ Test 4: vCard generation passed.');

// Test 5: Visual Font Size Hint (Largest letters on card = Company Name)
const sampleCard5 = `
SUNSHINE
Amit Kumar
Sales Manager
Mob: 9876543210
`;
const lineData5 = [
  { text: 'SUNSHINE', height: 75.0 },     // Largest font on card!
  { text: 'Amit Kumar', height: 40.0 },   // Medium font (Person Name)
  { text: 'Sales Manager', height: 25.0 },
  { text: 'Mob: 9876543210', height: 22.0 },
];
const result5 = CardParserService.parseBusinessCardText(sampleCard5, lineData5);
console.log('Result 5 (Visual Font Size Test):', JSON.stringify(result5, null, 2));

assert.strictEqual(result5.companyName, 'SUNSHINE', 'Largest font line must be Company Name');
assert.strictEqual(result5.personName, 'Amit Kumar', 'Person name must be Amit Kumar');

console.log('✓ Test 5: Visual letter size (largest font = Company Name) passed.');

// Test 6: Multi-Person Business Card (2 Partners with individual phone numbers)
const sampleCard6 = `
SHREEJI METALS
Rajesh Patel: 98250 12345
Dhrumil Patel: 97261 52534
Partners
info@shreejimetals.com
GIDC Phase 2, Vatva, Ahmedabad, Gujarat
`;

const result6 = CardParserService.parseBusinessCardText(sampleCard6);
console.log('Result 6 (Multi-Person Card with 2 Partners):', JSON.stringify(result6, null, 2));

assert.strictEqual(result6.companyName, 'SHREEJI METALS', 'Company should be SHREEJI METALS');
assert.strictEqual(result6.hasMultiplePersons, true, 'Card must be identified as having multiple persons');
assert.strictEqual(result6.detectedPersons?.length, 2, 'Must detect exactly 2 persons');

const person1 = result6.detectedPersons?.[0];
const person2 = result6.detectedPersons?.[1];

assert.ok(person1 && (person1.name === 'Rajesh Patel' || person1.name === 'Dhrumil Patel'), 'Person 1 must be detected');
assert.ok(person2 && (person2.name === 'Rajesh Patel' || person2.name === 'Dhrumil Patel'), 'Person 2 must be detected');
assert.notStrictEqual(person1?.name, person2?.name, 'The 2 detected persons must be distinct');
assert.strictEqual(person1?.designation, 'Partner', 'Designation should be normalized to Partner');
assert.strictEqual(person2?.designation, 'Partner', 'Designation should be normalized to Partner');
assert.ok(person1?.phone === '9825012345' || person1?.phone === '9726152534', 'Person 1 must have valid phone');
assert.ok(person2?.phone === '9825012345' || person2?.phone === '9726152534', 'Person 2 must have valid phone');

console.log('✓ Test 6: Multi-person card (2 partners with individual phones) passed.');

// Test 7: Multi-Person Joined by & with Individual Emails
const sampleCard7 = `
EXCEL TRADING CO.
Rajesh Sharma & Amit Verma
Directors
Mob: 9876543210, 9876543211
rajesh@exceltrading.com
amit@exceltrading.com
Mumbai, Maharashtra
`;

const result7 = CardParserService.parseBusinessCardText(sampleCard7);
console.log('Result 7 (Multi-Person Joined by &):', JSON.stringify(result7, null, 2));

assert.strictEqual(result7.hasMultiplePersons, true, 'Card with 2 directors joined by & must be multi-person');
assert.strictEqual(result7.detectedPersons?.length, 2, 'Must extract 2 distinct directors');
const r7P1 = result7.detectedPersons?.[0];
const r7P2 = result7.detectedPersons?.[1];
assert.strictEqual(r7P1?.name, 'Rajesh Sharma', 'First director should be Rajesh Sharma');
assert.strictEqual(r7P2?.name, 'Amit Verma', 'Second director should be Amit Verma');
assert.strictEqual(r7P1?.designation, 'Director', 'Designation should be Director');
assert.strictEqual(r7P2?.designation, 'Director', 'Designation should be Director');
assert.strictEqual(r7P1?.email, 'rajesh@exceltrading.com', 'Rajesh should be assigned rajesh@exceltrading.com');
assert.strictEqual(r7P2?.email, 'amit@exceltrading.com', 'Amit should be assigned amit@exceltrading.com');

console.log('✓ Test 7: Multi-person card joined by & with individual emails passed.');

// Test 8: IT Company Card with Services (Website, CRM, ERP, Apps)
const sampleCard8 = `
INNOTECH SOLUTIONS PVT. LTD.
Dhrumil Patel
Technical Director
Mo: 9726152534
dhrumil@innotech.com
www.innotech.com
Services: Website Development, Mobile App Development, Custom CRM, ERP Solutions
Ahmedabad, Gujarat
`;

const result8 = CardParserService.parseBusinessCardText(sampleCard8);
console.log('Result 8 (IT Card with Services):', JSON.stringify(result8, null, 2));

assert.strictEqual(result8.companyName, 'INNOTECH SOLUTIONS PVT. LTD.');
assert.strictEqual(result8.personName, 'Dhrumil Patel');
assert.ok(result8.servicesOffered?.includes('Website Development'), 'Must extract Website Development');
assert.ok(result8.servicesOffered?.includes('Custom CRM'), 'Must extract Custom CRM');
assert.ok(result8.servicesOffered?.includes('ERP Solutions'), 'Must extract ERP Solutions');
assert.strictEqual(result8.city, 'Ahmedabad');
assert.ok(!result8.address.includes('Website Development'), 'Address must NOT contain services');

console.log('✓ Test 8: IT company card services extraction passed.');

// Test 9: Finance Card with SIP, Insurance, Mutual Funds
const sampleCard9 = `
SHREE WEALTH MANAGEMENT
Rajesh Shah
Financial Advisor
Cell: 9825012345
We Deal In: SIP, Mutual Funds, Life Insurance, Health Insurance, Home Loans
Surat, Gujarat
`;

const result9 = CardParserService.parseBusinessCardText(sampleCard9);
console.log('Result 9 (Finance Card with SIP/Insurance):', JSON.stringify(result9, null, 2));

assert.strictEqual(result9.companyName, 'SHREE WEALTH MANAGEMENT');
assert.strictEqual(result9.personName, 'Rajesh Shah');
assert.ok(result9.servicesOffered?.includes('SIP'), 'Must extract SIP');
assert.ok(result9.servicesOffered?.includes('Mutual Funds'), 'Must extract Mutual Funds');
assert.ok(result9.servicesOffered?.includes('Life Insurance'), 'Must extract Life Insurance');
assert.ok(result9.servicesOffered?.includes('Home Loans'), 'Must extract Home Loans');

console.log('✓ Test 9: Finance card offerings (SIP/Insurance/Loans) passed.');

// Test 10: Manufacturing Card with Machines, Lathe, Die Casting
const sampleCard10 = `
APEX PRECISION ENGINEERING
Amit Verma
Operations Manager
Mob: 9876543210
Products: CNC Machine Parts, Lathe Job Work, Die Casting, Industrial Valves
Plot 45, GIDC Industrial Area, Vadodara, Gujarat - 390010
`;

const result10 = CardParserService.parseBusinessCardText(sampleCard10);
console.log('Result 10 (Manufacturing Card with CNC/Lathe):', JSON.stringify(result10, null, 2));

assert.strictEqual(result10.companyName, 'APEX PRECISION ENGINEERING');
assert.strictEqual(result10.personName, 'Amit Verma');
assert.ok(result10.servicesOffered?.includes('CNC Machine Parts'), 'Must extract CNC Machine Parts');
assert.ok(result10.servicesOffered?.includes('Lathe Job Work'), 'Must extract Lathe Job Work');
assert.ok(result10.servicesOffered?.includes('Die Casting'), 'Must extract Die Casting');
assert.ok(result10.address.includes('Plot 45'), 'Address should contain Plot 45');

console.log('✓ Test 10: Manufacturing card products (CNC/Lathe/Valves) passed.');

// Test 11: 2-Sided Card Scan (Front & Back merged)
const sampleCard11 = `
TECHCORP SYSTEMS
Rajesh Kumar
Managing Director
Mob: 9876543210
rajesh@techcorp.in

--- BACK SIDE ---
OUR CAPABILITIES:
• Custom CRM Development
• Cloud Hosting & DevOps
• Mobile Apps & Website
Branch: Bangalore, Pune
www.techcorp.in
`;

const result11 = CardParserService.parseBusinessCardText(sampleCard11);
console.log('Result 11 (2-Sided Card Scan):', JSON.stringify(result11, null, 2));

assert.strictEqual(result11.companyName, 'TECHCORP SYSTEMS');
assert.strictEqual(result11.personName, 'Rajesh Kumar');
assert.strictEqual(result11.phone, '9876543210');
assert.strictEqual(result11.website, 'https://www.techcorp.in');
assert.ok(result11.servicesOffered?.includes('Custom CRM Development'), 'Must extract CRM from back side');
assert.ok(result11.servicesOffered?.includes('Cloud Hosting & DevOps'), 'Must extract Cloud from back side');

console.log('✓ Test 11: 2-Sided card scan (Front & Back merged) passed.');

// Test 12: Real Card (Vidhi Consultancy) with Maulik Jadav and background keyboard keys "Enter" and "Shift"
const sampleCard12 = `
VIDHI CONSULTANCY
Leading Towards Reality
ISO 9001:2015
MAULIK JADAV
Business Development Executive
+91 9054904867
maulik.vidhiconsultancy@gmail.com
info@vidhiconsultancy.com
www.vidhiconsultancy.com
www.probatives.com
A 405-406, Titanium Business Park, B/h. Sammet Platinum, Nr. Makarba
Ahmedabad, Gujarat
Enter
Shift
`;

const result12 = CardParserService.parseBusinessCardText(sampleCard12);
console.log('Result 12 (Vidhi Consultancy with Keyboard Artifacts):', JSON.stringify(result12, null, 2));

assert.strictEqual(result12.companyName, 'VIDHI CONSULTANCY', 'Company name must be VIDHI CONSULTANCY');
assert.strictEqual(result12.personName, 'MAULIK JADAV', 'Person name must be MAULIK JADAV');
assert.strictEqual(result12.designation, 'Business Development Executive', 'Designation must be Business Development Executive');
assert.strictEqual(result12.phone, '+919054904867', 'Phone must be +919054904867');
assert.strictEqual(result12.city, 'Ahmedabad', 'City must be Ahmedabad');
assert.strictEqual(result12.state, 'Gujarat', 'State must be Gujarat');
assert.strictEqual(result12.hasMultiplePersons, false, 'Must NOT detect multiple persons on single-person card!');
assert.strictEqual(result12.detectedPersons?.length, 1, 'Must have exactly 1 person detected (Enter and Shift must be ignored)!');
assert.strictEqual(result12.detectedPersons?.[0].name, 'MAULIK JADAV');

console.log('✓ Test 12: Single-person card with keyboard artifacts passed (Enter/Shift ignored).');

// Test 13: Shri Siddhivinayak Enterprise (Gujarati name Sunnybhai, multi-line company, furniture services)
const sampleCard13 = `
Sunnybhai
M: 6354955982
Shri
Siddhivinayak
Enterprise
All Type of Office Chair
Manufacturing & Chair &
Sofa Repairing & Lining Work
Sofa, Chair & Carpet Shampoo Wash Available
Radhika Park Part-1, Arbudanagar, Chandlodiya,
Gota Road, Ahmedabad.
`;

const result13 = CardParserService.parseBusinessCardText(sampleCard13);
console.log('Result 13 (Shri Siddhivinayak Enterprise):', JSON.stringify(result13, null, 2));

assert.strictEqual(result13.companyName, 'Shri Siddhivinayak Enterprise', 'Company name must be full multi-line Shri Siddhivinayak Enterprise');
assert.strictEqual(result13.personName, 'Sunnybhai', 'Person name must be Sunnybhai');
assert.strictEqual(result13.phone, '6354955982', 'Phone must be 6354955982');
assert.strictEqual(result13.city, 'Ahmedabad', 'City must be Ahmedabad');
assert.strictEqual(result13.hasMultiplePersons, false, 'Must NOT detect fake 2nd person from services!');
assert.strictEqual(result13.detectedPersons?.length, 1, 'Must have exactly 1 person (Sunnybhai)!');
assert.strictEqual(result13.detectedPersons?.[0].name, 'Sunnybhai');
assert.ok(result13.servicesOffered?.includes('Chair') || result13.servicesOffered?.includes('Sofa'), 'Services must extract chair/sofa offerings');

console.log('✓ Test 13: Multi-line company, Gujarati suffix name, and services extraction passed.');

// Test 14: Real Card (Joganiya Electricals & Service / Gopalbhai)
const sampleCard14 = `
Gopalbhai
M. 74349 61011
Joganiya
Electricals & Service
Fan & Geyser Repair &
All Types of Electrical Works
Single Phase & Three Phase
`;

const result14 = CardParserService.parseBusinessCardText(sampleCard14);
console.log('Result 14 (Joganiya Electricals / Gopalbhai):', JSON.stringify(result14, null, 2));

assert.strictEqual(result14.personName, 'Gopalbhai', 'Person name must be Gopalbhai');
assert.strictEqual(result14.phone, '7434961011', 'Phone must be 7434961011');
assert.ok(result14.companyName.toLowerCase().includes('joganiya'), 'Company name must be Joganiya');
assert.strictEqual(result14.hasMultiplePersons, false, 'Must NOT detect fake 2nd person');
assert.strictEqual(result14.detectedPersons?.length, 1, 'Must have only 1 person (Gopalbhai)');
assert.strictEqual(result14.detectedPersons?.[0].name, 'Gopalbhai');

console.log('✓ Test 14: Electrical repair card with Gopalbhai passed.');

// Test 15: Real Card (D.M. Refilling / Dharmesh Bihola)
const sampleCard15 = `
Dharmesh Bihola
M: 9328256133
D.M. Refilling
On Site - Service
E-MAIL: DMREFILLING@GMAIL.COM
COMPLETE SOLUTION GENUINE
TONER, CARTRIDGE REFILLING
PRINTER REPAIRING & SERVICE
`;

const result15 = CardParserService.parseBusinessCardText(sampleCard15);
console.log('Result 15 (D.M. Refilling / Dharmesh Bihola):', JSON.stringify(result15, null, 2));

assert.strictEqual(result15.personName, 'Dharmesh Bihola', 'Person name must be Dharmesh Bihola');
assert.strictEqual(result15.phone, '9328256133', 'Phone must be 9328256133');
assert.ok(result15.companyName.toLowerCase().includes('refilling'), 'Company name must be D.M. Refilling');
assert.strictEqual(result15.hasMultiplePersons, false, 'Must NOT detect fake 2nd person');
assert.strictEqual(result15.detectedPersons?.length, 1, 'Must have only 1 person (Dharmesh Bihola)');
assert.strictEqual(result15.detectedPersons?.[0].name, 'Dharmesh Bihola');

console.log('✓ Test 15: Toner & Printer Refilling card with Dharmesh Bihola passed.');

// Test 16: Maheshwar card (OCR error +319876543210 -> +919876543210, Mahesh Hanat, MAHESHWAR company, Alt phone 919920453752)
const sampleCard16 = `
MAHESHWAR
Enterprise
Mahesh Hanat
+319967433981 / 919920453752
maheshhanat@gmail.com
All Printer Repairing & Cartridge Refilling
Fatehwadi Village, Ahemdabad, Gujarat-382210
`;

const result16 = CardParserService.parseBusinessCardText(sampleCard16);
console.log('Result 16 (Maheshwar / Mahesh Hanat with +31 fix):', JSON.stringify(result16, null, 2));

assert.strictEqual(result16.personName, 'Mahesh Hanat', 'Person name must be Mahesh Hanat');
assert.ok(result16.companyName.toLowerCase().includes('maheshwar'), 'Company name must include MAHESHWAR (never just Enterprise)');
assert.strictEqual(result16.phone, '+919967433981', 'Phone must fix +31 to +91 and capture all 10 digits');
assert.strictEqual(result16.alternativePhone, '+919920453752', 'Alt phone must format 919920453752 to +919920453752');
assert.strictEqual(result16.email, 'maheshhanat@gmail.com', 'Email must be maheshhanat@gmail.com');
assert.strictEqual(result16.hasMultiplePersons, false, 'Must NOT detect fake 2nd person');

console.log('✓ Test 16: Maheshwar card with +31 OCR error correction and MAHESHWAR company name passed.');

// Test 17: Yellow card OCR email variations (spaces around @, copyright symbol, missing dot, etc.)
const sampleCard17 = `
|| ॐ ||
Dharmesh Bihola
M: 9328256133
D.M. Refilling
COMPLETE SOLUTION GENUINE
TONER, CARTRIDGE REFILLING
PRINTER REPAIRING & SERVICE
On Site - Service
E-MAIL : DMREFILLING @ GMAIL.COM
`;

const result17 = CardParserService.parseBusinessCardText(sampleCard17);
console.log('Result 17 (Yellow Card with OCR spaced email):', JSON.stringify(result17, null, 2));

assert.strictEqual(result17.email, 'dmrefilling@gmail.com', 'Must extract email even with OCR spaces around @');
assert.strictEqual(result17.personName, 'Dharmesh Bihola', 'Person name must be Dharmesh Bihola');
assert.strictEqual(result17.phone, '9328256133', 'Phone must be 9328256133');

// Test 17b: Email with copyright symbol © or missing dot
const sampleEmails = CardParserService.extractEmails('E-MAIL : DMREFILLING©GMAIL.COM\nsupport@servicecom');
assert.ok(sampleEmails.includes('dmrefilling@gmail.com'), 'Must extract email when @ was scanned as ©');
assert.ok(sampleEmails.includes('support@service.com'), 'Must fix missing dot before com');

console.log('✓ Test 17: OCR email extraction with spaces, © symbols, and missing dots passed.');

// Test 18: Exact OCR Text from user phone for Yellow D.M. Refilling Card
const sampleCard18 = `
M
M:93282561 33
AsuRsua3
Dharmesh Bihola
M:9328256133
SAMSUNGCanon brother
L98106bs6+
D.M. Refilling
On Site - Service E-MAIL: DMREFILLING@GMAL COM
BAngaxg uaudojaAag Ssau
AVaVr NInV
COMPLETE SOLUTION GENUINE
TONER, CARTRIDGE REFILLING
PRINTER REPAIRING & SERVICE
GOr
Ge
Th
`;

const result18 = CardParserService.parseBusinessCardText(sampleCard18);
console.log('Result 18 (Exact Yellow Card OCR Text from Phone):', JSON.stringify(result18, null, 2));

assert.strictEqual(result18.personName, 'Dharmesh Bihola', 'Person name must be Dharmesh Bihola');
assert.strictEqual(result18.companyName, 'D.M. Refilling', 'Company name must be D.M. Refilling (never SERVICE)');
assert.strictEqual(result18.email, 'dmrefilling@gmail.com', 'Email must be dmrefilling@gmail.com despite @GMAL COM OCR error');
assert.strictEqual(result18.phone, '9328256133', 'Phone must be 9328256133');

console.log('✓ Test 18: Exact phone OCR text for D.M. Refilling yellow card passed.');

// Test 19: Card with Barcode, ISO, and Desk Background Numbers
// Ensures ONLY the genuine card mobile is extracted, and barcode / ISO / desk numbers are strictly rejected
const sampleCard19 = `
MAHESHWAR ENTERPRISE
Mahesh Hanat
Mob: 9967433981
ISO 9001:2015 CERTIFIED
GSTIN: 24AAAAA0000A1Z5
Barcode: 8901234567890
Desk SN: 1080240099
maheshhanat@gmail.com
Fatehwadi, Ahmedabad - 382210
`;

const result19 = CardParserService.parseBusinessCardText(sampleCard19);
console.log('Result 19 (Card with Barcode, GSTIN and Desk Noise):', JSON.stringify(result19, null, 2));

assert.strictEqual(result19.phone, '9967433981', 'Must strictly extract the labeled mobile number');
assert.strictEqual(result19.alternativePhone, '', 'Barcode and desk noise numbers must NEVER become alt phone');
assert.strictEqual(result19.email, 'maheshhanat@gmail.com', 'Email must match');
assert.strictEqual(result19.personName, 'Mahesh Hanat', 'Person name must match');

console.log('✓ Test 19: Barcode, ISO numbers, and desk noise strict rejection passed.');

// Test 20: Gujarat Bearing Co Card with 2 Persons and Trade Role Line
const sampleCard20 = `
Arunbhai Gandhi
Piyush Gandhi
Importers & Distributors
GUJARAT BEARING CO.
Plot No 30, Soma Kanji Ni Wadi, Savera Complex Lane,
B/h Milestone Canal Point, Khatodara, Nr. Udhna Darwaja Surat -395002 (INDIA)
+91- 98251 22283
Email: gbcbearings@gmail.com
@GUJARATBEARINGCO
NMB NACHI IVS RIA
`;

const result20 = CardParserService.parseBusinessCardText(sampleCard20);
console.log('Result 20 (Gujarat Bearing Co Card with 2 Persons):', JSON.stringify(result20, null, 2));

assert.strictEqual(result20.personName, 'Arunbhai Gandhi', 'Primary person name must be Arunbhai Gandhi');
assert.strictEqual(result20.hasMultiplePersons, true, 'hasMultiplePersons must be true');
assert.strictEqual(result20.detectedPersons?.length, 2, 'Must detect exactly 2 persons');
assert.strictEqual(result20.detectedPersons?.[1].name, 'Piyush Gandhi', 'Second person must be Piyush Gandhi');
assert.strictEqual(result20.companyName, 'GUJARAT BEARING CO.', 'Company name must be GUJARAT BEARING CO., never Importers & Distributors');
assert.strictEqual(result20.phone, '9825122283', 'Phone must match');
assert.strictEqual(result20.email, 'gbcbearings@gmail.com', 'Email must match');
assert.strictEqual(result20.city, 'Surat', 'City must match');
assert.strictEqual(result20.state, 'Gujarat', 'State must match');

console.log('✓ Test 20: Multi-person detection & company name disambiguation passed.');

console.log('\n======================================================');
console.log('ALL TYPESCRIPT BUSINESS CARD PARSER TESTS PASSED! 🎉');
console.log('======================================================\n');
