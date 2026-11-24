import { IParsedCardData, ILineData, IDetectedPerson } from '../types';

// Common generic email domains to exclude from company domain guessing
const GENERIC_EMAIL_DOMAINS = new Set([
  'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com',
  'rediffmail.com', 'protonmail.com', 'zoho.com', 'aol.com', 'mail.com',
  'ymail.com', 'live.com', 'msn.com', 'inbox.com', 'gmx.com'
]);

// Known professional designations and titles
const DESIGNATIONS = [
  'managing director', 'md', 'executive director', 'director', 'directors',
  'chief executive officer', 'ceo', 'chief technology officer', 'cto',
  'chief operating officer', 'coo', 'chief financial officer', 'cfo',
  'founder & ceo', 'co-founder & ceo', 'founder', 'co-founder', 'cofounder', 'founders', 'co-founders',
  'proprietor', 'prop.', 'prop', 'owner', 'owners', 'partner', 'partners', 'co-partner', 'co-partners',
  'president', 'vice president', 'vp', 'general manager', 'gm',
  'project manager', 'product manager', 'marketing manager', 'sales manager', 'operations manager',
  'branch manager', 'assistant manager', 'deputy manager', 'manager',
  'senior software engineer', 'sr. software engineer', 'software engineer',
  'lead developer', 'senior developer', 'full stack developer', 'frontend developer', 'backend developer', 'developer',
  'system architect', 'solution architect', 'technical architect', 'architect',
  'business development manager', 'bdm', 'business development executive', 'bde',
  'senior consultant', 'management consultant', 'tax consultant', 'consultant', 'advisor',
  'sales executive', 'marketing executive', 'account executive', 'executive',
  'chartered accountant', 'advocate', 'lawyer', 'attorney', 'legal advisor',
  'physician', 'surgeon', 'dentist', 'specialist', 'doctor',
  'team lead', 'technical lead', 'tech lead', 'team leader',
  'data scientist', 'data analyst', 'business analyst', 'analyst',
  'creative director', 'art director', 'ui/ux designer', 'graphic designer', 'designer',
  'administrator', 'coordinator', 'supervisor', 'officer', 'representative'
];

// Keywords indicating company, organizational or commercial names
const COMPANY_INDICATORS = [
  'pvt ltd', 'pvt. ltd.', 'private limited', 'pvt.', 'pvt',
  'ltd', 'ltd.', 'limited', 'llc', 'inc', 'inc.', 'corp', 'corp.', 'corporation',
  'co.', 'co', 'company',
  'enterprises', 'enterprise', 'solutions', 'services', 'service',
  'technologies', 'technology', 'tech', 'industries', 'industry', 'industrial',
  'group', 'ventures', 'associates', 'agency', 'traders', 'trading', 'impex',
  'mart', 'bazaar', 'store', 'stores', 'shoppe', 'shop', 'centre', 'center',
  'works', 'studios', 'studio', 'creations', 'infotech', 'consultancy', 'consulting',
  'holdings', 'systems', 'software', 'digital', 'hardware', 'motors', 'automobiles',
  'electricals', 'electrical', 'refilling',
  'jewellers', 'jeweller', 'jewels', 'textiles', 'textile', 'garments', 'fabrics',
  'pharma', 'pharmaceuticals', 'chemicals', 'chem', 'healthcare', 'hospital',
  'clinic', 'diagnostics', 'labs', 'laboratory', 'logistics', 'transport', 'cargo',
  'infra', 'infrastructure', 'buildcon', 'builders', 'developers', 'construction',
  'properties', 'realty', 'realtors', 'estate', 'foods', 'products', 'distribution',
  'distributors', 'exports', 'imports', 'international', 'global', 'overseas',
  'foundation', 'trust', 'academy', 'institute', 'hotel', 'restaurant', 'cafe'
];

// Address indicator keywords
const ADDRESS_KEYWORDS = [
  'road', 'rd', 'rd.', 'street', 'st', 'st.', 'lane', 'avenue', 'ave',
  'nagar', 'colony', 'sector', 'sec', 'phase', 'block', 'plot', 'park',
  'floor', 'flat', 'office', 'shop', 'suite', 'room', 'cabin',
  'tower', 'complex', 'arcade', 'enclave', 'plaza', 'building', 'bldg',
  'near', 'opp', 'opposite', 'behind', 'b/h', 'nr', 'beside', 'next to',
  'cross', 'main road', 'highway', 'bypass', 'industrial area', 'gidc', 'midc'
];

// Major Indian States & UTs
const INDIAN_STATES = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
  'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
  'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
  'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
  'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
  'Delhi', 'Chandigarh', 'Puducherry', 'Jammu & Kashmir', 'Ladakh'
];

// Major Cities
const MAJOR_CITIES = [
  'Mumbai', 'Delhi', 'Bangalore', 'Bengaluru', 'Hyderabad', 'Ahmedabad',
  'Chennai', 'Kolkata', 'Surat', 'Pune', 'Jaipur', 'Lucknow', 'Kanpur',
  'Nagpur', 'Indore', 'Thane', 'Bhopal', 'Visakhapatnam', 'Pimpri-Chinchwad',
  'Patna', 'Vadodara', 'Ghaziabad', 'Ludhiana', 'Agra', 'Nashik', 'Faridabad',
  'Meerut', 'Rajkot', 'Kalyan-Dombivli', 'Vasai-Virar', 'Varanasi', 'Srinagar',
  'Aurangabad', 'Dhanbad', 'Amritsar', 'Navi Mumbai', 'Allahabad', 'Prayagraj',
  'Ranchi', 'Howrah', 'Coimbatore', 'Jabalpur', 'Gwalior', 'Vijayawada',
  'Jodhpur', 'Madurai', 'Raipur', 'Kota', 'Guwahati', 'Chandigarh', 'Solapur',
  'Hubli', 'Dharwad', 'Bareilly', 'Moradabad', 'Mysore', 'Gurgaon', 'Gurugram',
  'Noida', 'Greater Noida', 'Kochi', 'Dehradun', 'New York', 'London', 'Dubai', 'Singapore'
];

// Common personal first names and surnames to distinguish persons from companies
const COMMON_PERSON_NAMES = new Set([
  'patel', 'shah', 'sharma', 'verma', 'gupta', 'mehta', 'singh', 'kumar', 'rao', 'reddy', 'nair',
  'joshi', 'desai', 'pandey', 'mishra', 'tripathi', 'tiwari', 'yadav', 'agarwal', 'agrawal',
  'choudhary', 'chowdhury', 'malhotra', 'kapoor', 'khanna', 'chopra', 'bhatia', 'arora', 'bansal',
  'goyal', 'jain', 'modi', 'thakkar', 'trivedi', 'bhatt', 'vyas', 'parmar', 'solanki', 'chavda',
  'makwana', 'chauhan', 'rathod', 'jadeja', 'vaghela', 'sheth', 'dave', 'rawal', 'panchal', 'soni',
  'khatri', 'gandhi', 'dalal', 'munshi', 'parikh', 'amin', 'deshmukh', 'patil', 'kulkarni',
  'shinde', 'gaikwad', 'pawar', 'sawant', 'more', 'jadhav', 'jadav', 'bose', 'banerjee', 'chatterjee',
  'mukherjee', 'das', 'sen', 'ghosh', 'roy', 'dutta', 'ganguly', 'mitra', 'sengupta', 'chakraborty',
  'pillai', 'menon', 'kurian', 'mathew', 'thomas', 'varghese', 'iyer', 'iyengar', 'swaminathan',
  'krishnan', 'subramanian', 'raman', 'natarajan', 'balasubramanian', 'venkatesh', 'srinivasan',
  'murthy', 'hegde', 'shetty', 'rai', 'kamath', 'pai', 'prabhu', 'nayak', 'ali', 'khan', 'shaikh',
  'sheikh', 'ansari', 'siddiqui', 'qureshi', 'ahmed', 'sayyad', 'smith', 'johnson', 'williams',
  'brown', 'jones', 'garcia', 'miller', 'davis', 'wilson', 'anderson', 'taylor',
  'dhrumil', 'maulik', 'rajesh', 'amit', 'rahul', 'rohit', 'sachin', 'priya', 'pooja', 'neha', 'anita',
  'sanjay', 'vijay', 'ajay', 'sunil', 'anil', 'deepak', 'manoj', 'alok', 'vikas', 'ashok',
  'suresh', 'ramesh', 'mahesh', 'kamlesh', 'naresh', 'bhavesh', 'hitesh', 'jignesh', 'kalpesh',
  'pratik', 'chirag', 'hardik', 'harsh', 'jay', 'meet', 'karan', 'vishal', 'ankit', 'gaurav',
  'saurabh', 'mayank', 'sumit', 'kunal', 'varun', 'arjun', 'vivek', 'abhishek', 'aditya', 'ayush',
  'dhruv', 'parth', 'shubham', 'tushar', 'mohit', 'nitin', 'pankaj', 'pradeep', 'sandip', 'sandeep',
  'bhavik', 'nikunj', 'piyush', 'chetan', 'ketan', 'vipul', 'bharat', 'paresh', 'mukesh', 'hiten',
  'dhaval', 'kishan', 'shailesh', 'chandresh', 'jayesh', 'dinesh', 'manish', 'prakash',
  'sunny', 'sunnybhai', 'sunilbhai', 'anilbhai', 'rajeshbhai', 'dhrumilbhai', 'maulikbhai', 'amitbhai',
  'sanjaybhai', 'vijaybhai', 'ajaybhai', 'maheshbhai', 'rameshbhai', 'sureshbhai', 'kamleshbhai',
  'bhaveshbhai', 'hiteshbhai', 'jigneshbhai', 'pankajbhai', 'mukeshbhai', 'ketanbhai', 'vipulbhai',
  'pareshbhai', 'hitenbhai', 'dhavalbhai', 'kishanbhai', 'chetanbhai', 'nitinbhai', 'pradeepbhai',
  'sandeepbhai', 'gopalbhai', 'gopal', 'manishbhai', 'ashokbhai', 'dineshbhai', 'bharatbhai', 'babubhai',
  'dharmesh', 'bihola'
]);

// Non-person words, keyboard keys, and common OCR artifacts to reject from person names
const INVALID_PERSON_WORDS = new Set([
  // Products, furniture, services & action words (NEVER human names)
  'sofa', 'chair', 'chairs', 'carpet', 'shampoo', 'wash', 'repairing', 'repair', 'repairs',
  'lining', 'work', 'works', 'cushion', 'cushions', 'furniture', 'wood', 'all type of', 'available',
  'manufacturing', 'manufacturer', 'manufacturers', 'fabrication', 'fitting', 'cleaning',
  'electrical', 'electricals', 'geyser', 'fan', 'printer', 'refilling', 'cartridge', 'toner',
  'single phase', 'three phase', 'service', 'services', 'on site', 'genuine', 'solution', 'complete solution',

  // Keyboard keys and hardware UI (scanned from laptop/desk backgrounds)
  'enter', 'shift', 'ctrl', 'control', 'alt', 'space', 'tab', 'caps', 'lock',
  'esc', 'escape', 'delete', 'del', 'backspace', 'insert', 'home', 'end',
  'page', 'up', 'down', 'left', 'right', 'print', 'screen', 'prtscn', 'pause', 'break',
  'fn', 'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8', 'f9', 'f10', 'f11', 'f12',
  'num', 'scroll', 'cmd', 'command', 'option', 'return',
  'menu', 'file', 'edit', 'view', 'window', 'help', 'tools', 'search',
  'scan', 'card', 'front', 'back', 'next', 'prev', 'previous', 'save', 'cancel',
  'submit', 'done', 'close', 'open', 'exit', 'quit', 'start', 'stop',
  'click', 'press', 'tap', 'select', 'choose', 'check', 'copy', 'paste',

  // Slogans, certifications, common card headings
  'iso', 'certified', 'quality', 'trusted', 'towards', 'reality',
  'leading', 'innovating', 'growing', 'excellence', 'commitment',
  'services', 'products', 'offerings', 'specialist',
  
  // Designations that shouldn't stand alone as names
  'executive', 'director', 'manager', 'officer', 'engineer', 'associate',
  'consultant', 'partner', 'partners', 'founder', 'founders', 'proprietor',
  'development', 'management', 'technical', 'financial', 'operations',
  
  // Organization and location words
  'consultancy', 'solutions', 'enterprises', 'enterprise', 'technologies',
  'associates', 'industries', 'group', 'agency', 'company', 'office',
  'branch', 'head', 'corporate', 'regd', 'registered',
  'website', 'email', 'phone', 'mobile', 'cell', 'tel', 'fax', 'address',
  'near', 'opp', 'opposite', 'behind', 'beside', 'road', 'street',
  'highway', 'complex', 'plaza', 'tower', 'building', 'floor', 'block',
  'india', 'gujarat', 'maharashtra', 'ahmedabad', 'mumbai', 'delhi', 'surat', 'vadodara'
]);

export class CardParserService {
  /**
   * Main entry point: Parses raw OCR text into structured contact fields
   */
  static parseBusinessCardText(rawText: string, lineData?: ILineData[]): IParsedCardData {
    if (!rawText || typeof rawText !== 'string' || rawText.trim().length === 0) {
      return {
        personName: '',
        companyName: '',
        designation: '',
        phone: '',
        alternativePhone: '',
        email: '',
        website: '',
        address: '',
        city: '',
        state: '',
        country: 'India',
        gstNumber: '',
        category: 'Business',
        servicesOffered: '',
        rawText: '',
        missingFields: ['personName', 'phone', 'email'],
        hasMultiplePersons: false,
        detectedPersons: [],
      };
    }

    // Split text into non-empty trimmed lines
    const lines = rawText
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter((line) => line.length > 0);

    const fullText = lines.join(' \n ');

    // 1. Extract Email Addresses (handles OCR spaces around @, symbols like ©/(a), missing dots, and E-MAIL labels)
    const emails = this.extractEmails(fullText, lines);
    const primaryEmail = emails.length > 0 ? emails[0] : '';

    // 2. Extract Websites
    const websites = this.extractWebsites(fullText, primaryEmail);
    const primaryWebsite = websites.length > 0 ? websites[0] : '';

    // 3. Extract Phone Numbers (Multi-number & label aware)
    const phones = this.extractPhoneNumbers(lines, fullText);
    const primaryPhone = phones.length > 0 ? phones[0] : '';
    const alternativePhone = phones.length > 1 ? phones[1] : '';

    // 4. Extract GST Number
    const gstNumber = this.extractGST(fullText);

    // 5. Extract Designation (Job Title)
    const designationResult = this.extractDesignation(lines);

    // 6. Extract Products & Services Offered (IT, Finance, Manufacturing, Healthcare, etc.)
    const servicesData = this.extractServicesAndProducts(lines);

    // 7. Extract Location & Address (excluding services lines)
    const locationData = this.extractLocationAndAddress(lines, servicesData.matchedLineIndexes);

    // 8. Intelligently Disambiguate Person Name vs Company Name & Multi-Person Detection
    const disambiguation = this.extractPersonAndCompany(lines, {
      primaryEmail,
      emails,
      primaryWebsite,
      designationResult,
      locationData,
      phones,
      lineData,
      servicesLineIndexes: servicesData.matchedLineIndexes,
    });

    const personName = disambiguation.personName;
    const companyName = disambiguation.companyName;
    const finalDesignation = disambiguation.primaryDesignation || designationResult.designation;
    const finalPhone = disambiguation.primaryPhone || primaryPhone;
    const finalAltPhone = disambiguation.alternativePhone || alternativePhone;
    const hasMultiplePersons = disambiguation.hasMultiplePersons || false;
    const detectedPersons = disambiguation.detectedPersons || [];

    // 9. Compute missing fields
    const missingFields: string[] = [];
    if (!personName) missingFields.push('personName');
    if (!finalPhone) missingFields.push('phone');
    if (!primaryEmail) missingFields.push('email');
    if (!companyName) missingFields.push('companyName');

    return {
      personName,
      companyName,
      designation: finalDesignation,
      phone: finalPhone,
      alternativePhone: finalAltPhone,
      email: primaryEmail,
      website: primaryWebsite,
      address: locationData.address,
      city: locationData.city,
      state: locationData.state,
      country: locationData.country || 'India',
      gstNumber,
      category: 'Business',
      servicesOffered: servicesData.services,
      rawText,
      missingFields,
      hasMultiplePersons,
      detectedPersons,
    };
  }

  /**
   * Extract all valid email addresses (robust to OCR spaces around @, © for @, typos like gmal, missing dots, space before TLD, and E-MAIL labels)
   */
  static extractEmails(text: string, lines?: string[]): string[] {
    const emails: string[] = [];

    const normalizeEmailCandidate = (raw: string): string => {
      let clean = raw.trim().toLowerCase();
      // Remove leading labels like "email:", "e-mail:", "mail:", "email id:", "e - mail :"
      clean = clean.replace(/^(?:e[\s-]*mail|mail|email\s*id)\s*[:.-]?\s*/i, '');
      // Fix spaces around @ and .
      clean = clean.replace(/\s*[@©]\s*/g, '@').replace(/\s*\.\s*/g, '.');
      // Fix (a) or (at) or [at] -> @
      clean = clean.replace(/(?:[([]?at[)\]]|[(]a[)])/gi, '@');
      // Fix common OCR domain misspellings like gmal, gmall, gmai, yaho, hotmial
      clean = clean
        .replace(/@\s*g(?:ma|m|mai|mal|mall|maill|maii|gmai)\s*[.\s]+\s*(?:co[mn]?|in|co\.in)\b/gi, '@gmail.com')
        .replace(/@\s*g(?:ma|m|mai|mal|mall|maill|maii|gmai)com\b/gi, '@gmail.com')
        .replace(/@\s*yaho[ou]?\s*[.\s]+\s*(?:co[mn]?|in)\b/gi, '@yahoo.com')
        .replace(/@\s*hotmial?\s*[.\s]+\s*(?:co[mn]?|in)\b/gi, '@hotmail.com')
        .replace(/@\s*outloo?k\s*[.\s]+\s*(?:co[mn]?|in)\b/gi, '@outlook.com');
      // Fix space before TLD: e.g. "@domain com" -> "@domain.com" or "@gmail com" -> "@gmail.com"
      clean = clean.replace(/@([a-z0-9._-]+)\s+(com|in|co\.in|org|net|io|edu|gov|biz|info)\b/gi, '@$1.$2');
      // Fix missing dot before common TLDs: e.g. @gmailcom -> @gmail.com or @servicecom -> @service.com
      clean = clean.replace(/@([a-z0-9._-]+?)(com|org|net|in|co\.in|io)\b/gi, '@$1.$2');
      // Fix .c0m -> .com
      clean = clean.replace(/\.c0m\b/gi, '.com');
      // Fix double dots
      clean = clean.replace(/\.\.+/g, '.');
      // Remove trailing punctuation
      clean = clean.replace(/[.,;:\s]+$/, '').trim();
      return clean;
    };

    const addCleanEmail = (raw: string) => {
      const clean = normalizeEmailCandidate(raw);
      // Check if candidate itself is a valid email
      const validEmailMatch = clean.match(/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/);
      if (validEmailMatch && !emails.includes(clean)) {
        emails.push(clean);
        return;
      }
      // If candidate had surrounding words (e.g. "On Site - Service E-MAIL: DMREFILLING@GMAL COM"), extract inner email
      const innerMatch = clean.match(/([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/i);
      if (innerMatch && !emails.includes(innerMatch[1].toLowerCase())) {
        emails.push(innerMatch[1].toLowerCase());
      }
    };

    // 1. Scan explicit email label lines (e.g. "On Site - Service E-MAIL: DMREFILLING@GMAL COM")
    const allLines = lines || text.split(/\r?\n/);
    const emailLabelRegex = /(?:\be[\s-]*mail\b|\bmail\b|\bemail\s*id\b)\s*[:.-]?\s*(.*)/i;
    for (const line of allLines) {
      const match = line.match(emailLabelRegex);
      if (match && match[1]) {
        addCleanEmail(match[1]);
        if (emails.length > 0) continue;
      }
    }

    // 2. Pre-process text to fix OCR spaces, typos and missing dots across fullText
    let normalizedText = text
      .replace(/\s*[@©]\s*/g, '@')
      .replace(/@\s*g(?:ma|m|mai|mal|mall|maill|maii|gmai)\s*[.\s]+\s*(?:co[mn]?|in|co\.in)\b/gi, '@gmail.com')
      .replace(/@\s*g(?:ma|m|mai|mal|mall|maill|maii|gmai)com\b/gi, '@gmail.com')
      .replace(/@([a-z0-9._-]+)\s+(com|in|co\.in|org|net|io|edu|gov|biz|info)\b/gi, '@$1.$2')
      .replace(/\s*\.\s*/g, '.')
      .replace(/\.\.+/g, '.')
      .replace(/@([a-z0-9._-]+?)(com|org|net|in|co\.in|io)\b/gi, '@$1.$2');

    const emailRegex = /([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})/gi;
    const matches = normalizedText.match(emailRegex) || [];
    for (const m of matches) {
      addCleanEmail(m);
    }

    // 3. Fallback scan for common email domains if OCR split across words or used O/0/space instead of @
    // e.g. "DMREFILLING GMAIL.COM" or "DMREFILLING@GMAL COM" or "DMREFILLINGOGMAIL.COM"
    if (emails.length === 0) {
      const looseDomainRegex = /([a-zA-Z0-9._%+-]+)[\s@©0oO]+(gmail|yahoo|hotmail|outlook|rediffmail|icloud|gmal|gmall)\s*[.\s]?\s*(com|in|co\.in)\b/gi;
      let looseMatch: RegExpExecArray | null;
      while ((looseMatch = looseDomainRegex.exec(text)) !== null) {
        addCleanEmail(`${looseMatch[1]}@${looseMatch[2]} ${looseMatch[3]}`);
      }
    }

    return [...new Set(emails)];
  }

  /**
   * Extract website URLs
   */
  static extractWebsites(text: string, primaryEmail: string): string[] {
    const emailDomain = primaryEmail && primaryEmail.includes('@') ? primaryEmail.split('@')[1] : null;
    const urlRegex = /(?:https?:\/\/|www\.)[^\s/$.?#].[^\s]*|[a-zA-Z0-9-]+\.(?:com|org|net|in|co\.in|io|biz|info|ai|tech|app|me|co)\b/gi;
    const matches = text.match(urlRegex) || [];

    const websites: string[] = [];
    for (const url of matches) {
      let cleaned = url.trim().replace(/[.,;:]$/, '');
      if (cleaned.includes('@')) continue;

      // Discard generic email provider domains from being marked as websites
      const cleanDomain = cleaned.replace(/^https?:\/\//i, '').replace(/^www\./i, '').toLowerCase();
      if (GENERIC_EMAIL_DOMAINS.has(cleanDomain)) continue;
      if (emailDomain && cleaned.toLowerCase() === emailDomain.toLowerCase()) {
        cleaned = `www.${cleaned}`;
      }
      if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
        cleaned = cleaned.startsWith('www.') ? `https://${cleaned}` : `https://www.${cleaned}`;
      }
      if (!websites.includes(cleaned)) {
        websites.push(cleaned);
      }
    }
    return websites;
  }

  /**
   * Extract Phone Numbers (strictly validates telecom formats and blocks barcodes, GSTIN, PIN codes & background noise)
   */
  static extractPhoneNumbers(lines: string[], fullText: string): string[] {
    const phones: string[] = [];

    // Helper to add clean validated phone
    const addClean = (raw: string) => {
      const cleaned = this.cleanPhoneNumber(raw);
      if (cleaned && !phones.includes(cleaned)) {
        phones.push(cleaned);
      }
    };

    // Words / labels indicating phone numbers
    const phoneLabelRegex = /(?:\bmob(?:ile)?\b|\bcell(?:ular)?\b|\bph(?:one)?\b|\btel(?:ephone)?\b|\bcontact\b|\bcall\b|\bwhatsapp\b|\bmo\.?|\bm\.?|\bph\.?)\s*[:.-]?\s*(.*)/i;

    // 1. First priority: Extract numbers from lines explicitly labeled as phone/mobile
    for (const line of lines) {
      // Disqualify if line is GSTIN or barcode
      if (/\b(?:GST(?:IN)?|ISO|CIN|REG|LIC|BARCODE)\b/i.test(line)) continue;

      const labelMatch = line.match(phoneLabelRegex);
      if (labelMatch && labelMatch[1]) {
        // Split line if it contains multiple numbers separated by slash, comma, ampersand, or pipe
        const chunks = labelMatch[1].split(/[/,|&]/);
        for (const chunk of chunks) {
          // Look for 10-digit mobile or standard phone numbers in chunk
          const numMatches = chunk.match(/(?:\+(?:91|31)[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b|(?:\+(?:91|31)[\s-]?)?[6-9]\d{9}\b|\b91[6-9]\d{9}\b|\b[6-9]\d{9}\b/g);
          if (numMatches) {
            for (const n of numMatches) addClean(n);
          } else {
            addClean(chunk);
          }
        }
      }
    }

    // If labeled phone numbers were found on the card, return them immediately!
    // Do NOT scrape random unlabeled numbers from the desk or card background.
    if (phones.length > 0) {
      return phones;
    }

    // 2. Secondary scan: ONLY if no labeled phone was found on the card,
    // look for standalone 10-digit mobile numbers, strictly verifying they are not PIN codes, GST, or barcodes
    for (const line of lines) {
      // Ignore lines that are addresses, tax info, website, or email
      if (line.includes('@') || line.includes('www.') || line.includes('http')) continue;
      if (/\b(?:GST(?:IN)?|ISO|CIN|REG|LIC|PIN|P\.?O\.?|FLAT|FLOOR|ROAD|STREET|AVENUE|NAGAR|SECTOR|HIGHWAY)\b/i.test(line)) continue;
      // Reject lines with barcodes or long 13+ digit numbers
      if (/\b\d{13,}\b/.test(line)) continue;

      const chunks = line.split(/[/,|&]/);
      for (const chunk of chunks) {
        const standaloneMatches = chunk.match(/(?:\+(?:91|31)[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b|(?:\+(?:91|31)[\s-]?)?[6-9]\d{9}\b|\b91[6-9]\d{9}\b|\b[6-9]\d{9}\b|(?:\+[1-9]\d{1,2}[\s-]?)?[6-9]\d{9,10}\b/g) || [];
        for (const num of standaloneMatches) {
          addClean(num);
        }
      }
    }

    return phones;
  }

  static cleanPhoneNumber(raw: string): string | null {
    if (!raw) return null;
    let clean = raw.trim().replace(/[^\d+]/g, '');

    // Disqualify if too short or if it's a 6-digit Indian PIN code
    if (clean.length < 10 || clean.length === 6) return null;

    // Fix OCR misreading +91 as +31 or 31 before Indian mobile (e.g. +319876543210 -> +919876543210)
    if (/^\+?31[6-9]\d{9}$/.test(clean)) {
      const mobile10 = clean.replace(/^\+?31/, '');
      return `+91${mobile10}`;
    }

    // Indian mobile with 91 or +91: e.g. +919920453752 or 919920453752 -> +919920453752
    if (/^(\+?91)[6-9]\d{9}$/.test(clean)) {
      const mobile10 = clean.replace(/^\+?91/, '');
      return `+91${mobile10}`;
    }

    // Disqualify 12+ digit barcode numbers without valid country code
    if (clean.length >= 12 && !clean.startsWith('+')) return null;

    // Normal Indian 10-digit mobile without country code: e.g. 9822012345
    if (/^[6-9]\d{9}$/.test(clean)) {
      return clean;
    }

    // Leading 0 on Indian mobile: e.g. 09920453752 -> +919920453752
    if (/^0[6-9]\d{9}$/.test(clean)) {
      return `+91${clean.slice(1)}`;
    }

    // Landline with STD code (e.g. 0792685XXXX)
    if (/^0[1-9]\d{8,10}$/.test(clean)) {
      return clean;
    }

    // Verified international mobile with + (e.g. +14155552671)
    if (clean.startsWith('+') && clean.length >= 11 && clean.length <= 15) {
      return clean;
    }

    return null;
  }

  /**
   * Extract 15-character Indian GSTIN
   */
  static extractGST(text: string): string {
    const gstRegex = /\b\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\b/g;
    const matches = text.match(gstRegex);
    if (matches && matches.length > 0) {
      return matches[0];
    }

    const labelMatch = text.match(/GST(?:IN)?\s*[:.-]?\s*([0-9A-Z]{15})/i);
    if (labelMatch && labelMatch[1]) {
      return labelMatch[1].toUpperCase();
    }
    return '';
  }

  /**
   * Extract Designation (Job Title)
   */
  static extractDesignation(lines: string[]): { designation: string; lineIndex: number } {
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const lower = line.toLowerCase();

      // If line begins with personal honorifics (Dr., Mr., etc.), it's a Person Name, NOT a designation!
      if (/^(?:dr|mr|mrs|ms|prof|shri|smt)\.?\s+/i.test(line)) continue;

      for (const desig of DESIGNATIONS) {
        const regex = new RegExp(`\\b${desig}\\b`, 'i');
        if (regex.test(lower)) {
          let formatted = line;
          if (line.includes(',') || line.includes('|') || line.includes('-')) {
            const parts = line.split(/[,|\-]/);
            for (const part of parts) {
              if (new RegExp(`\\b${desig}\\b`, 'i').test(part.trim())) {
                formatted = part.trim();
                break;
              }
            }
          }
          return {
            designation: this.capitalizeTitle(formatted),
            lineIndex: i,
          };
        }
      }
    }
    return { designation: '', lineIndex: -1 };
  }

  // Service & Product Domain Keywords across industries (IT, Finance, Manufacturing, Healthcare, etc.)
  static readonly SERVICE_KEYWORDS = [
    // IT, Software & Digital Offerings
    'website development', 'web development', 'web design', 'software development', 'custom software',
    'crm solutions', 'crm development', 'crm', 'erp solutions', 'erp system', 'erp implementation', 'erp',
    'mobile app development', 'app development', 'mobile apps', 'android app', 'ios app',
    'cloud services', 'cloud hosting', 'cloud computing', 'devops', 'api integration', 'cyber security',
    'digital marketing', 'seo services', 'seo', 'social media marketing', 'graphic design', 'ui/ux design',
    'ecommerce solutions', 'e-commerce', 'domain registration', 'web hosting',

    // Finance, Investment & Insurance Offerings
    'sip', 'systematic investment plan', 'mutual funds', 'mutual fund', 'life insurance',
    'health insurance', 'general insurance', 'mediclaim', 'term insurance', 'term plan',
    'demat account', 'share market', 'equity trading', 'derivatives', 'commodity',
    'fixed deposit', 'fixed deposits', 'portfolio management', 'wealth management',
    'financial planning', 'retirement planning', 'tax saving', 'income tax', 'itr filing',
    'home loan', 'personal loan', 'business loan', 'mortgage loan', 'project loan', 'loans',

    // Manufacturing, Industrial Machinery, Engineering & Tools
    'cnc machine', 'cnc machining', 'cnc job work', 'cnc parts', 'vmc machine', 'vmc machining', 'lathe machine',
    'lathe job work', 'lathe work', 'laser cutting', 'plasma cutting', 'sheet metal fabrication',
    'sheet metal components', 'metal fabrication', 'fabrication work', 'die casting', 'pressure die casting',
    'plastic moulding', 'injection moulding', 'mould making', 'machining', 'job work', 'machine',
    'industrial valves', 'valves', 'pumps', 'bearings', 'hydraulic systems', 'pneumatic systems',
    'spare parts', 'automotive parts', 'fasteners', 'hardware tools', 'power tools',

    // Printing, Packaging, Toner Refilling & Advertising
    'offset printing', 'digital printing', 'flex printing', 'screen printing', 'packaging boxes',
    'corrugated boxes', 'carton boxes', 'brochures', 'catalogues', 'flyers', 'stickers', 'labels',
    'toner refilling', 'cartridge refilling', 'printer repairing', 'printer repair', 'printer service',
    'toner', 'cartridge', 'refilling', 'on site service',

    // Real Estate, Interior & Construction
    'interior designing', 'interior design', 'interior decorator', 'modular kitchen',
    'civil construction', 'building construction', 'turnkey projects', 'renovation',
    'architectural planning', 'residential flats', 'commercial offices', 'plots', 'bungalows',

    // Healthcare, Medical & Diagnostics
    'dental implants', 'root canal', 'cosmetic dentistry', 'orthodontics',
    'cardiology', 'orthopedics', 'pediatrics', 'gynecology', 'pathology laboratory',
    'diagnostics', 'physiotherapy', 'radiology', 'x-ray', 'opd', 'icu',

    // Furniture, Carpentry, Upholstery & Cleaning Services
    'office chair', 'chair manufacturing', 'chair repair', 'chair repairing', 'chair',
    'sofa repairing', 'sofa repair', 'sofa', 'lining work', 'lining', 'cushion work', 'cushion',
    'shampoo wash', 'carpet shampoo', 'carpet wash', 'carpet cleaning', 'carpet',
    'shampoo wash available', 'foam wash', 'upholstery cleaning', 'dry cleaning',
    'furniture manufacturing', 'furniture repair', 'furniture', 'wood work', 'carpentry',
    'repairing', 'maintenance', 'installation', 'job work', 'all type of', 'all types of', 'available',

    // Textiles, Apparel & Wholesale
    'sarees', 'fabrics', 'yarn', 'textiles', 'garments', 'suitings', 'shirtings',
    'industrial chemicals', 'pharmaceutical formulations', 'cosmetics', 'food products'
  ];

  /**
   * Extracts Products, Services, or Business Offerings from card lines.
   * Returns formatted services text and line indexes to exclude from company/address fields.
   */
  static extractServicesAndProducts(lines: string[]): {
    services: string;
    matchedLineIndexes: number[];
  } {
    const matchedLineIndexes: number[] = [];
    const collectedItems: string[] = [];

    // Header prefix regex for products and services
    const headerPrefixRegex = /^(?:(?:our\s+)?services?(?:\s+offered)?|(?:our\s+)?products?(?:\s+range)?|we\s+deal\s+in|deal(?:s|ing)?\s+in|specialis(?:t|ed|ing)\s+in|specializ(?:ed|ing)\s+in|mfrs?\.?\s+of|manufacturers?\s+of|suppliers?\s+of|distributors?\s+of|dealers?\s+in|all\s+types\s+of|solutions\s+for|expertise\s+in|key\s+offerings?|activities)\s*[:.-]?\s*(.*)/i;

    let inServiceSection = false;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      const lower = line.toLowerCase();

      // Skip lines that are contact/location details or section breaks
      if (line.includes('@')) continue;
      if (line.includes('www.') || line.includes('http')) continue;
      if (/\b(?:\+?91[\s-]?)?[6-9]\d{9}\b/.test(line)) continue;
      if (/\b(?:GST(?:IN)?|ISO|CIN|REG|LIC|BARCODE|SERIAL|SN|MODEL|SKU|BATCH)\b/i.test(line)) continue;
      if (line.startsWith('---') && line.endsWith('---')) continue;

      // 1. Check for explicit Section Header (e.g. "Services: Website, CRM, ERP" or "We Deal In: ...")
      const headerMatch = line.match(headerPrefixRegex);
      if (headerMatch) {
        matchedLineIndexes.push(i);
        inServiceSection = true;
        const remainder = headerMatch[1].trim();
        if (remainder.length > 0) {
          const parts = remainder.split(/[,|/•*;\n]/).map((s) => s.trim()).filter((s) => s.length >= 2);
          for (const p of parts) collectedItems.push(p);
        }
        continue;
      }

      // 2. If in service section, collect subsequent bullet lines or list items
      if (inServiceSection) {
        const isAddressLine = ADDRESS_KEYWORDS.some((kw) => new RegExp(`\\b${kw}\\b`, 'i').test(lower));
        const isCityLine = MAJOR_CITIES.some((c) => new RegExp(`\\b${c}\\b`, 'i').test(lower));
        if (isAddressLine || isCityLine || line.length > 80) {
          inServiceSection = false;
        } else {
          matchedLineIndexes.push(i);
          const cleaned = line.replace(/^[•✓★*▪\-–\d.)]\s*/, '').trim();
          const parts = cleaned.split(/[,|/•*;\n]/).map((s) => s.trim()).filter((s) => s.length >= 2);
          for (const p of parts) collectedItems.push(p);
          continue;
        }
      }

      // 3. Bullet-pointed lines, service action lines, or lines containing service keywords
      const startsWithBullet = /^[•✓★*▪\-–]\s+/.test(line);
      const matchedKeywords = this.SERVICE_KEYWORDS.filter((kw) => {
        return new RegExp(`\\b${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(lower);
      });
      const hasServiceAction = /\b(?:repairing|repair|repairs|refilling|lining|manufacturing|manufacturers|fabrication|washing|cleaning|shampoo|maintenance|installation|servicing|service|services|job work|wash available)\b/i.test(lower);
      const hasProductOrServiceItem = /\b(?:sofa|chair|chairs|carpet|cushion|furniture|office chair|printer|printers|cartridge|cartridges|toner|toners|laptop|laptops|computer|hardware|software|machine|machinery|valves|pumps|bearings|valves|tools)\b/i.test(lower);

      // If bullet point and has at least 1 keyword
      if (startsWithBullet && (matchedKeywords.length >= 1 || hasServiceAction)) {
        matchedLineIndexes.push(i);
        const cleaned = line.replace(/^[•✓★*▪\-–\d.)]\s*/, '').trim();
        collectedItems.push(cleaned);
        continue;
      }

      // If line contains service keywords or service action with products
      if (
        matchedKeywords.length >= 2 ||
        (matchedKeywords.length >= 1 && (line.includes(',') || line.includes('|') || line.includes('/') || line.includes('&'))) ||
        (hasServiceAction && (hasProductOrServiceItem || line.includes('&') || line.includes(','))) ||
        (lower.startsWith('all type') && (hasProductOrServiceItem || hasServiceAction)) ||
        /\b(?:complete solution|genuine toner|printer repairing)\b/i.test(lower) ||
        /\b(?:importers?\s*(?:&|and)\s*distributors?|dealers?\s*(?:&|and)\s*distributors?|manufacturers?\s*(?:&|and)\s*traders?|exporters?\s*(?:&|and)\s*importers?|wholesalers?\s*(?:&|and)\s*retailers?|stockists?\s*(?:&|and)\s*distributors?|stockists?\s*(?:&|and)\s*dealers?|authorised?\s+dealers?|authorized?\s+dealers?)\b/i.test(lower)
      ) {
        const hasAddress = ADDRESS_KEYWORDS.some((kw) => new RegExp(`\\b${kw}\\b`, 'i').test(lower));
        if (!hasAddress) {
          matchedLineIndexes.push(i);
          const parts = line.split(/[,|/•*;\n]/).map((s) => s.trim()).filter((s) => s.length >= 2);
          for (const p of parts) collectedItems.push(p);
          continue;
        }
      }
    }

    // Clean, deduplicate and format collected items
    const uniqueItems: string[] = [];
    for (const item of collectedItems) {
      const clean = item.replace(/^[•✓★*▪\-–:]\s*/, '').replace(/[:.-]$/, '').trim();
      if (clean.length >= 2 && !uniqueItems.some((u) => u.toLowerCase() === clean.toLowerCase())) {
        uniqueItems.push(clean);
      }
    }

    return {
      services: uniqueItems.join(', '),
      matchedLineIndexes,
    };
  }

  /**
   * Extract City, State, Country and Address
   */
  static extractLocationAndAddress(lines: string[], excludedIndexes: number[] = []) {
    let detectedCity = '';
    let detectedState = '';
    const detectedCountry = 'India';
    const addressLines: string[] = [];
    const matchedLineIndexes: number[] = [];
    const pinRegex = /\b([1-9]\d{5})\b/;

    for (let i = 0; i < lines.length; i++) {
      if (excludedIndexes.includes(i)) continue;
      const line = lines[i];
      const lower = line.toLowerCase();

      const hasAddressKeyword = ADDRESS_KEYWORDS.some((kw) =>
        new RegExp(`\\b${kw}\\b`, 'i').test(lower)
      );
      const hasPin = pinRegex.test(line);

      for (const city of MAJOR_CITIES) {
        if (new RegExp(`\\b${city}\\b`, 'i').test(line) && !detectedCity) {
          detectedCity = city;
        }
      }

      for (const state of INDIAN_STATES) {
        if (new RegExp(`\\b${state}\\b`, 'i').test(line) && !detectedState) {
          detectedState = state;
        }
      }

      const hasCompanyIndicator = COMPANY_INDICATORS.some((ind) =>
        new RegExp(`\\b${ind}\\b`, 'i').test(lower)
      );

      // Address line: has PIN code, has address keywords, or is a pure city/state location line without company indicators
      const isPureCityStateLine = !hasCompanyIndicator && line.split(/\s+/).length <= 4 && (
        MAJOR_CITIES.some((c) => new RegExp(`\\b${c}\\b`, 'i').test(lower)) ||
        INDIAN_STATES.some((s) => new RegExp(`\\b${s}\\b`, 'i').test(lower))
      );

      if (hasPin || hasAddressKeyword || isPureCityStateLine) {
        // If line contains company indicator without PIN code or explicit address marker, do not treat as address
        const hasExplicitAddressMarker = /\b(?:plot|road|rd|street|st|lane|building|bldg|floor|flat|shop|suite|block|sector|gidc|midc|opp|near|behind|b\/h|nr)\b/i.test(lower);
        if (hasCompanyIndicator && !hasPin && !hasExplicitAddressMarker) {
          continue;
        }

        addressLines.push(line);
        if (!matchedLineIndexes.includes(i)) {
          matchedLineIndexes.push(i);
        }
      }
    }

    let finalAddress = addressLines.join(', ');
    finalAddress = finalAddress.replace(/,\s*,/g, ',').replace(/\s+/g, ' ').trim();

    return {
      address: finalAddress,
      city: detectedCity,
      state: detectedState,
      country: detectedCountry,
      matchedLineIndexes,
    };
  }

  /**
   * Intelligently disambiguate Person Name and Company Name, and detect multiple persons if present.
   * Scores all non-contact lines to ensure Person Name and Company Name are NEVER swapped.
   */
  static extractPersonAndCompany(
    lines: string[],
    context: {
      primaryEmail: string;
      emails?: string[];
      primaryWebsite: string;
      designationResult: { designation: string; lineIndex: number };
      locationData: { matchedLineIndexes: number[] };
      phones: string[];
      lineData?: ILineData[];
      servicesLineIndexes?: number[];
    }
  ): {
    personName: string;
    companyName: string;
    primaryDesignation?: string;
    primaryPhone?: string;
    alternativePhone?: string;
    hasMultiplePersons: boolean;
    detectedPersons: IDetectedPerson[];
  } {
    const { primaryEmail, emails = [], primaryWebsite, designationResult, locationData, phones, lineData, servicesLineIndexes = [] } = context;

    interface ICandidate {
      text: string;
      lineIndex: number;
      personScore: number;
      companyScore: number;
      inlinePhone?: string;
      inlineDesignation?: string;
      wasSplitLine?: boolean;
    }

    const candidates: ICandidate[] = [];

    // Map bounding box font heights if provided from ML Kit
    let maxFontHeight = 0;
    const heightMap = new Map<string, number>();

    if (lineData && Array.isArray(lineData)) {
      for (const item of lineData) {
        if (item.text && item.height) {
          const t = item.text.trim();
          heightMap.set(t, item.height);
          // Only track font height of non-contact, non-number lines
          if (!t.includes('@') && !t.includes('www.') && !/\d{6,}/.test(t)) {
            if (item.height > maxFontHeight) {
              maxFontHeight = item.height;
            }
          }
        }
      }
    }

    // Extract username prefix from email (e.g. "dhrumil" from "dhrumil226@gmail.com")
    const emailPrefix = primaryEmail ? primaryEmail.split('@')[0].toLowerCase().replace(/[^a-z]/g, '') : '';

    // Extract domain from website or email
    let customDomain = '';
    if (primaryWebsite) {
      const m = primaryWebsite.match(/https?:\/\/(?:www\.)?([^/]+)/i);
      if (m && m[1]) {
        const domainParts = m[1].split('.');
        if (domainParts[0] && !GENERIC_EMAIL_DOMAINS.has(`${domainParts[0]}.com`)) {
          customDomain = domainParts[0].toLowerCase();
        }
      }
    }
    if (!customDomain && primaryEmail && primaryEmail.includes('@')) {
      const domain = primaryEmail.split('@')[1].toLowerCase();
      if (!GENERIC_EMAIL_DOMAINS.has(domain)) {
        customDomain = domain.split('.')[0];
      }
    }

    // 0. Detect Multi-Line Company Names (e.g. "Shri" + "Siddhivinayak" + "Enterprise")
    for (let i = 0; i < lines.length; i++) {
      const line1 = lines[i].trim();
      if (line1.includes('@') || line1.includes('http') || line1.includes('www.') || line1.includes('.com') || locationData.matchedLineIndexes.includes(i) || servicesLineIndexes.includes(i)) continue;
      if (/(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}|^(?:m\.|mob|cell|ph)\b|\b\d{5}[\s-]\d{5}\b/i.test(line1)) continue;

      for (let span = 2; span <= 3; span++) {
        if (i + span > lines.length) break;
        const slice = lines.slice(i, i + span).map((s) => s.trim());
        const hasBadLine = slice.some((s, idx) => {
          const actualIdx = i + idx;
          const hasHonorific = /^(?:mr|mrs|ms|dr|er|prof)\.?\s+/i.test(s);
          const hasNameSuffix = /(?:bhai|ben|bahen)$/i.test(s);
          const isDesignationLine = actualIdx === designationResult.lineIndex;
          const hasPhone = /(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}|^(?:m\.|mob|cell|ph)\b|\b\d{5}[\s-]\d{5}\b/i.test(s);
          const hasIndicator = COMPANY_INDICATORS.some((ind) => new RegExp(`\\b${ind}\\b`, 'i').test(s));
          const isExcludedService = servicesLineIndexes.includes(actualIdx) && !hasIndicator;
          const hasDigitsOrCode = /\d{2,}/.test(s);
          return s.includes('@') || s.includes('http') || s.includes('www.') || s.includes('.com') || locationData.matchedLineIndexes.includes(actualIdx) || isExcludedService || hasPhone || hasDigitsOrCode || s.length < 2 || hasHonorific || hasNameSuffix || isDesignationLine;
        });
        if (hasBadLine) continue;

        // If last line already contains brand + indicator (e.g. "D.M. Refilling"), don't join preceding lines
        const lastWords = slice[slice.length - 1].trim().split(/\s+/);
        const lastHasNonIndicator = lastWords.some((w) => {
          const wLower = w.toLowerCase().replace(/[^a-z]/g, '');
          return wLower.length >= 2 && !COMPANY_INDICATORS.some((ind) => ind === wLower);
        });
        const isSelfContainedCompany = lastWords.length >= 2 && lastHasNonIndicator && !/^(?:shri|shree|sri|m\/s|om)\b/i.test(slice[slice.length - 1]);
        if (isSelfContainedCompany) continue;

        const combined = slice.join(' ');
        const lowerCombined = combined.toLowerCase();
        const hasCompInd = COMPANY_INDICATORS.some((ind) => new RegExp(`\\b${ind}\\b`, 'i').test(lowerCombined));
        const startsWithPrefix = /^(?:shri|shree|sri|m\/s|om|jay|jai)\s+/i.test(combined);

        const lastLineLower = slice[slice.length - 1].toLowerCase();
        const lastHasCompInd = COMPANY_INDICATORS.some((ind) => new RegExp(`\\b${ind}\\b`, 'i').test(lastLineLower));
        const firstHasPrefix = /^(?:shri|shree|sri|m\/s|om|jay|jai)\b/i.test(slice[0]);

        if ((lastHasCompInd && firstHasPrefix) || (lastHasCompInd && slice.every((s) => s.split(/\s+/).length <= 3))) {
          let compScore = 120;
          if (lastHasCompInd) compScore += 60;
          if (startsWithPrefix) compScore += 40;

          // Associate font height with multi-line candidate if available
          const sliceHeights = slice.map((s) => heightMap.get(s) || 0);
          const maxSliceHeight = Math.max(...sliceHeights, 0);
          if (maxSliceHeight > 0) {
            heightMap.set(combined, maxSliceHeight);
            if (maxFontHeight > 0 && maxSliceHeight >= maxFontHeight * 0.8) {
              compScore += 95;
            }
          }

          candidates.push({
            text: combined,
            lineIndex: i,
            personScore: -150,
            companyScore: compScore,
            wasSplitLine: false,
          });
        }
      }
    }

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      const lower = line.toLowerCase();

      // Skip lines that are obvious contact or location details
      if (line.includes('@')) continue;
      if (line.includes('www.') || line.includes('http')) continue;
      if (locationData.matchedLineIndexes.includes(i)) continue;
      if (servicesLineIndexes.includes(i)) continue;
      if (/\b(?:GST(?:IN)?|ISO|CIN|REG|LIC|BARCODE|SERIAL|SN|MODEL|SKU|BATCH)\b/i.test(line)) continue;
      if (line.startsWith('---') && line.endsWith('---')) continue;

      // Check if line is purely phone numbers with no person name or letters
      const lettersCount = (line.match(/[a-zA-Z]/g) || []).length;
      if (lettersCount < 3) continue;

      // Check if line is pure designation or matches designationResult
      if (designationResult.lineIndex === i) {
        // Only evaluate if line contains an explicit person honorific or known person surname
        const hasPerson = /^(?:mr|mrs|ms|dr|er|prof|shri|smt)\.?\s+/i.test(line) ||
          line.split(/\s+/).some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, '')));
        if (!hasPerson) continue;
      }

      // Skip lines that are purely phone numbers or labeled contact lines without person names
      if (/^(?:mob|mobile|cell|ph|phone|tel|telephone|contact|call|fax|whatsapp)\s*[:.-]/i.test(line)) {
        // Only evaluate if it contains a clear person name or honorific before/in the line
        const hasName = /^(?:mr|mrs|ms|dr|er|prof|shri|smt)\.?\s+/i.test(line) ||
          line.split(/\s+/).some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, '')));
        if (!hasName) continue;
      }

      // Check if line has a phone number mixed in, e.g. "Rajesh Patel: 98250 12345" or "Dhrumil Patel - 9726152534"
      let inlinePhone: string | undefined;
      let textToScore = line;
      const phoneInLine = line.match(/(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b|(?:\+?91[\s-]?)?[6-9]\d{9}\b/);
      if (phoneInLine) {
        const cleaned = CardParserService.cleanPhoneNumber(phoneInLine[0]);
        if (cleaned && (phones.includes(cleaned) || phones.length === 0)) {
          inlinePhone = cleaned;
          // Strip all phone numbers, spaces within numbers, and phone labels
          textToScore = line
            .replace(/(?:\+?91[\s-]?)?[6-9]\d{4}[\s-]?\d{5}\b/g, '')
            .replace(/(?:\+?91[\s-]?)?[6-9]\d{9}\b/g, '')
            .replace(/\b\d{5}[\s-]?\d{5}\b/g, '')
            .replace(/\b\d{10,12}\b/g, '')
            .replace(/^(?:mob|mobile|cell|ph|phone|contact|call|mo\.?|m\.?)\s*[:.-]?/i, '')
            .replace(/[:|/-]\s*$/, '')
            .replace(/^\s*[:|/-]/, '')
            .trim();
        }
      }

      // If textToScore still has 4+ digits, it's not a person name
      if (/\d{4,}/.test(textToScore)) continue;

      // Filter out lines that are only phone label remnants (e.g. "Mob", "Cell")
      const remainingAlpha = textToScore.replace(/[^a-zA-Z]/g, '');
      if (remainingAlpha.length < 3) continue;
      if (/^(?:mob|mobile|cell|ph|phone|tel|telephone|contact|call|fax|whatsapp)$/i.test(remainingAlpha)) continue;

      // Check if line contains an inline designation, e.g. "Rajesh Patel (Partner)" or "Rajesh Patel - Director"
      let inlineDesignation: string | undefined;
      for (const desig of DESIGNATIONS) {
        const reg = new RegExp(`(?:[(-]|^|\\b)\\s*${desig}\\s*(?:[)]|$|[:-])`, 'i');
        if (reg.test(textToScore)) {
          let cleanDesig = desig;
          if (cleanDesig.toLowerCase() === 'partners') cleanDesig = 'Partner';
          if (cleanDesig.toLowerCase() === 'directors') cleanDesig = 'Director';
          if (cleanDesig.toLowerCase() === 'owners') cleanDesig = 'Owner';
          inlineDesignation = CardParserService.capitalizeTitle(cleanDesig);
          textToScore = textToScore.replace(new RegExp(`[(-]?\\s*\\b${desig}\\b\\s*[)]?`, 'gi'), '').trim();
          textToScore = textToScore.replace(/^[|:,-]\s*/, '').replace(/\s*[|:,-]$/, '').trim();
          break;
        }
      }

      // If textToScore has multiple names separated by & or and or / (e.g. "Rajesh Patel & Dhrumil Patel")
      const splitMatch = textToScore.split(/\s+(?:&|and|\/)\s+/i);
      const subTexts: { text: string; wasSplitLine: boolean }[] = [];
      const hasInvalidWordsInLine = splitMatch.some((part) => {
        const pLower = part.toLowerCase();
        return INVALID_PERSON_WORDS.has(pLower) ||
          part.split(/\s+/).some((w) => INVALID_PERSON_WORDS.has(w.toLowerCase().replace(/[^a-z0-9]/g, '')));
      });
      const hasHumanNameInSplit = splitMatch.some((part) => {
        const words = part.split(/\s+/).map((w) => w.toLowerCase().replace(/[^a-z]/g, ''));
        return words.some((w) => COMMON_PERSON_NAMES.has(w)) ||
          /(?:bhai|ben|bahen|kumar|lal|ji|rao)$/i.test(part) ||
          /^(?:mr|mrs|ms|dr|er|prof)\.?\s+/i.test(part);
      });

      if (
        splitMatch.length === 2 &&
        !hasInvalidWordsInLine &&
        hasHumanNameInSplit &&
        splitMatch.every((part) => (part.match(/[a-zA-Z]/g) || []).length >= 3)
      ) {
        subTexts.push(
          { text: splitMatch[0].trim(), wasSplitLine: true },
          { text: splitMatch[1].trim(), wasSplitLine: true }
        );
      } else {
        subTexts.push({ text: textToScore, wasSplitLine: false });
      }

      for (const item of subTexts) {
        const subClean = item.text.trim();
        const wasSplitLine = item.wasSplitLine;
        if (subClean.length < 3) continue;

        let personScore = 10;
        let companyScore = 10;

        const words = subClean.split(/\s+/).filter((w) => w.length > 0);
        const subLower = subClean.toLowerCase();
        const hasHonorific = /^(?:mr|mrs|ms|dr|er|prof|shri|smt)\.?\s+/i.test(subClean);
        const hasCompanyIndicator = COMPANY_INDICATORS.some((ind) =>
          new RegExp(`\\b${ind}\\b`, 'i').test(subLower)
        );

        // Disqualify known invalid words, keyboard keys, or slogans
        const isInvalidWord = INVALID_PERSON_WORDS.has(subLower) ||
          words.some((w) => INVALID_PERSON_WORDS.has(w.toLowerCase().replace(/[^a-z0-9]/g, '')));

        if (isInvalidWord) {
          personScore = -999;
          companyScore -= 80;
        }

        // --- PERSON SCORING ---
        if (hasHonorific) {
          personScore += 50;
          companyScore -= 40;
        }

        const hasKnownPersonName = words.some((w) =>
          COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, ''))
        );
        if (hasKnownPersonName) {
          personScore += 60;
          companyScore -= 50;
        }

        if (inlineDesignation) {
          personScore += 45;
          companyScore -= 30;
        } else if (designationResult.lineIndex !== -1 && !isInvalidWord) {
          // Only reward designation proximity if candidate has at least 2 words or has an honorific/known name
          if (words.length >= 2 || hasHonorific || hasKnownPersonName) {
            if (Math.abs(i - designationResult.lineIndex) <= 2) {
              personScore += 45;
              companyScore -= 30;
            }
          }
        }

        if (emailPrefix.length >= 3) {
          const matchesEmail = words.some((w) => emailPrefix.includes(w.toLowerCase()) && w.length >= 3);
          if (matchesEmail) {
            personScore += 35;
            companyScore -= 20;
          }
        }

        // Gujarati / Indian personal name suffixes (-bhai, -ben, -bahen, -kumar, -lal, -ji, -rao)
        const hasNameSuffix = /(?:bhai|ben|bahen|kumar|lal|ji|rao)$/i.test(subClean) &&
          !/(?:mumbai|chennai|dubai)$/i.test(subLower);
        if (hasNameSuffix) {
          personScore += 75;
          companyScore -= 50;
        }

        if (words.length >= 2 && words.length <= 3) {
          personScore += 20;
        } else if (words.length === 1) {
          const single = words[0].toLowerCase().replace(/[^a-z]/g, '');
          if (hasHonorific || hasNameSuffix || COMMON_PERSON_NAMES.has(single)) {
            personScore += 35;
          } else {
            // Single word like "Enter" or "Shift" without honorific or inline designation
            personScore -= 60;
          }
        } else if (words.length > 4) {
          personScore -= 25;
        }

        const isTitleCase = words.every((w) => /^[A-Z][a-z]*$/.test(w));
        if (isTitleCase && !hasCompanyIndicator && !isInvalidWord) {
          personScore += 15;
        }

        if (hasCompanyIndicator) {
          personScore -= 80;
          companyScore += 70;
        }

        // --- COMPANY SCORING ---
        if (hasCompanyIndicator) {
          companyScore += 50;
        }

        if (customDomain && subLower.includes(customDomain)) {
          companyScore += 45;
          personScore -= 20;
        }

        const candidateAlpha = subLower.replace(/[^a-z]/g, '');
        if (emailPrefix.length >= 4 && candidateAlpha.length >= 4) {
          if (emailPrefix.includes(candidateAlpha) || candidateAlpha.includes(emailPrefix)) {
            companyScore += 55;
            personScore -= 30;
          }
        }

        // Email prefix contains major word from candidate (e.g. "gbcbearings" contains "bearing" from "GUJARAT BEARING CO.")
        const candidateWords = subLower.split(/\s+/).map((w) => w.replace(/[^a-z]/g, '')).filter((w) => w.length >= 4);
        if (emailPrefix.length >= 4 && candidateWords.some((w) => emailPrefix.includes(w) || (w.endsWith('s') && emailPrefix.includes(w.slice(0, -1))) || (!w.endsWith('s') && emailPrefix.includes(w + 's')))) {
          companyScore += 50;
        }

        if (/^(?:m\/s|shree|sri|om)\s+/i.test(subClean)) {
          companyScore += 30;
        }

        if (i === 0 && !hasHonorific && designationResult.lineIndex !== 1 && !hasKnownPersonName && !inlineDesignation) {
          companyScore += 25;
        }

        // Visual Font Height Evaluation (The Company Name is written in the LARGEST letters on the card!)
        const visualHeight = heightMap.get(subClean) || heightMap.get(line) || 0;
        if (maxFontHeight > 0 && visualHeight > 0) {
          if (visualHeight >= maxFontHeight * 0.80) {
            if (!hasHonorific && !hasKnownPersonName && !inlineDesignation) {
              companyScore += 95;
              personScore -= 40;
            } else {
              personScore += 40;
            }
          } else if (visualHeight >= maxFontHeight * 0.50 && visualHeight < maxFontHeight * 0.80) {
            personScore += 25;
          } else if (visualHeight < maxFontHeight * 0.40) {
            companyScore -= 25;
          }
        } else if (maxFontHeight === 0) {
          if (subClean === subClean.toUpperCase() && words.length >= 2 && !hasKnownPersonName && !hasHonorific && !inlineDesignation) {
            companyScore += 35;
          }
        }

        candidates.push({
          text: subClean,
          lineIndex: i,
          personScore,
          companyScore,
          inlinePhone,
          inlineDesignation,
          wasSplitLine,
        });
      }
    }

    // Disqualify generic indicator-only words from winning as company names (e.g. "Enterprise", "Consultancy", "Services", "Service", "Repairing")
    for (const cand of candidates) {
      const lower = cand.text.trim().toLowerCase();
      const isPureIndicator = COMPANY_INDICATORS.some(
        (ind) => ind === lower || ind.replace(/\./g, '') === lower
      );
      if (isPureIndicator && cand.text.split(/\s+/).length <= 2) {
        cand.companyScore -= 250;
      }
      if (['service', 'services', 'repairing', 'repair', 'solution', 'solutions', 'enterprise', 'enterprises', 'consultancy', 'trading'].includes(lower)) {
        cand.companyScore = -999;
      }
      if (/\b(?:importers?\s*(?:&|and)\s*distributors?|dealers?\s*(?:&|and)\s*distributors?|manufacturers?\s*(?:&|and)\s*traders?|exporters?\s*(?:&|and)\s*importers?|wholesalers?\s*(?:&|and)\s*retailers?|stockists?\s*(?:&|and)\s*distributors?|stockists?\s*(?:&|and)\s*dealers?|authorised?\s+dealers?|authorized?\s+dealers?)\b/i.test(lower)) {
        cand.companyScore = -999;
      }
    }

    const pureIndicators = candidates.filter((c) => {
      const lower = c.text.trim().toLowerCase();
      return COMPANY_INDICATORS.some((ind) => ind === lower || ind.replace(/\./g, '') === lower) && c.text.split(/\s+/).length <= 2;
    });

    const multiWordCompanies = candidates.filter((c) => c.text.includes(' ') && c.companyScore > 50);

    // Look for brand name candidates that can be combined with an UNCOMBINED pure indicator (e.g. "MAHESHWAR" + "Enterprise" -> "MAHESHWAR Enterprise")
    const uncombinedIndicators = pureIndicators.filter((ind) => {
      return !multiWordCompanies.some((m) =>
        new RegExp(`\\b${ind.text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(m.text)
      );
    });

    if (uncombinedIndicators.length > 0) {
      const brandCandidates = candidates.filter((c) => {
        const words = c.text.split(/\s+/);
        const lower = c.text.toLowerCase();
        const hasPerson = words.some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, '')));
        const hasSuffix = /(?:bhai|ben|bahen)$/i.test(c.text);
        const isPure = COMPANY_INDICATORS.some((ind) => ind === lower);
        const alreadyHasIndicator = COMPANY_INDICATORS.some((ind) => new RegExp(`\\b${ind}\\b`, 'i').test(lower));
        const isPrefixOnly = /^(?:shri|shree|sri|m\/s|om|jay|jai)$/i.test(lower);
        return !hasPerson && !hasSuffix && !isPure && !alreadyHasIndicator && !isPrefixOnly && c.text.length >= 3 && !INVALID_PERSON_WORDS.has(lower);
      });

      if (brandCandidates.length > 0) {
        brandCandidates.sort((a, b) => b.companyScore - a.companyScore);
        const bestBrand = brandCandidates[0];
        const bestInd = uncombinedIndicators[0];
        if (!new RegExp(`\\b${bestInd.text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(bestBrand.text)) {
          const combinedName = `${bestBrand.text} ${bestInd.text}`;
          candidates.push({
            text: combinedName,
            lineIndex: bestBrand.lineIndex,
            personScore: -150,
            companyScore: 240,
            wasSplitLine: false,
          });
        }
      }
    }

    // If a multi-word company candidate exists (e.g. "Shri Siddhivinayak Enterprise" or "MAHESHWAR Enterprise"),
    // penalize single-word fragments like "Enterprise" or "Shri" so the full name is picked
    const finalMultiWordCompanies = candidates.filter((c) => c.text.includes(' ') && c.companyScore > 50);
    if (finalMultiWordCompanies.length > 0) {
      for (const cand of candidates) {
        if (!cand.text.includes(' ')) {
          const isFragment = finalMultiWordCompanies.some((m) =>
            new RegExp(`\\b${cand.text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i').test(m.text)
          );
          if (isFragment) {
            cand.companyScore -= 120;
          }
        }
      }
    }

    // Pick best company name
    let companyName = '';
    const sortedByCompany = [...candidates]
      .filter((c) => c.companyScore > c.personScore || (c.companyScore > 30 && !c.inlineDesignation))
      .sort((a, b) => b.companyScore - a.companyScore);

    if (sortedByCompany.length > 0 && sortedByCompany[0].companyScore > 15) {
      companyName = this.cleanCompanyName(sortedByCompany[0].text);
    }

    if (!companyName && customDomain && customDomain.length > 2) {
      companyName = this.capitalizeTitle(customDomain.replace(/[-_]/g, ' '));
    }

    // Filter person candidates (must not match company name and must not be invalid words)
    const personCandidates = candidates.filter((c) => {
      const clean = this.cleanPersonName(c.text);
      const cleanLower = clean.toLowerCase();
      const compClean = companyName.toLowerCase();
      if (cleanLower === compClean || compClean.includes(cleanLower)) return false;
      if (INVALID_PERSON_WORDS.has(cleanLower)) return false;
      const words = clean.split(/\s+/).filter((w) => w.length > 0);
      if (words.some((w) => INVALID_PERSON_WORDS.has(w.toLowerCase().replace(/[^a-z0-9]/g, '')))) return false;
      const hasNameSuffix = /(?:bhai|ben|bahen|kumar|lal|ji|rao)$/i.test(clean) && !/(?:mumbai|chennai|dubai)$/i.test(cleanLower);
      if (words.length === 1 && !hasNameSuffix && !COMMON_PERSON_NAMES.has(words[0].toLowerCase()) && !/^(?:mr|mrs|ms|dr|er|prof)\.?/i.test(clean)) {
        return false;
      }
      return c.personScore >= 20 && c.personScore >= c.companyScore;
    });

    personCandidates.sort((a, b) => b.personScore - a.personScore);

    const uniquePersons: ICandidate[] = [];
    if (personCandidates.length > 0) {
      // 1. Primary person is always the top scored candidate
      uniquePersons.push(personCandidates[0]);

      // Check if card has a plural designation (Partners, Directors, Founders, Owners, Proprietors)
      const hasPluralDesignation = /^(?:partners|directors|founders|owners|proprietors)$/i.test(
        (designationResult.designation || '').trim()
      );

      // 2. Secondary persons MUST meet strict validation criteria (never stray words or keyboard keys)
      for (let idx = 1; idx < personCandidates.length; idx++) {
        const cand = personCandidates[idx];
        const cleanName = this.cleanPersonName(cand.text);
        const words = cleanName.split(/\s+/).filter((w) => w.length > 0);

        const alreadyExists = uniquePersons.some(
          (u) => this.cleanPersonName(u.text).toLowerCase() === cleanName.toLowerCase()
        );
        if (alreadyExists) continue;

        const wasSplitFromLine = cand.wasSplitLine === true && (
          words.some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, ''))) ||
          words.length >= 2
        );
        const hasOwnPhone = Boolean(cand.inlinePhone);
        const hasOwnDesignation = Boolean(cand.inlineDesignation);
        const hasMatchingEmail = emails.some((e) => {
          const prefix = e.split('@')[0].toLowerCase();
          return words.some((w) => w.length >= 3 && prefix.includes(w.toLowerCase()));
        });
        const isValidPluralPartner = hasPluralDesignation && words.length >= 2 && words.some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase()));

        // Independent multi-line person candidate (e.g. Arunbhai Gandhi & Piyush Gandhi on separate lines)
        const hasNameSuffix = /(?:bhai|ben|bahen|kumar|lal|ji|rao)$/i.test(cleanName) && !/(?:mumbai|chennai|dubai)$/i.test(cleanName.toLowerCase());
        const hasHonorific = /^(?:mr|mrs|ms|dr|er|prof|shri|smt)\.?\s+/i.test(cleanName);
        const hasKnownPersonWord = words.some((w) => COMMON_PERSON_NAMES.has(w.toLowerCase().replace(/[^a-z]/g, '')));
        const hasHighPersonScore = cand.personScore >= 35 && words.length >= 2 && words.length <= 3 && (hasKnownPersonWord || hasNameSuffix || hasHonorific);

        if (wasSplitFromLine || hasOwnPhone || hasOwnDesignation || hasMatchingEmail || isValidPluralPartner || hasHighPersonScore) {
          uniquePersons.push(cand);
        }

        if (uniquePersons.length >= 2) break;
      }
    }

    // Build detectedPersons array
    const detectedPersons: IDetectedPerson[] = [];
    const allEmails = emails.length > 0 ? emails : primaryEmail ? [primaryEmail] : [];

    for (let idx = 0; idx < uniquePersons.length; idx++) {
      const cand = uniquePersons[idx];
      const name = this.cleanPersonName(cand.text);

      // Designation
      let desig = cand.inlineDesignation || '';
      if (!desig && designationResult.designation) {
        let globalDesig = designationResult.designation;
        if (globalDesig.toLowerCase() === 'partners') globalDesig = 'Partner';
        if (globalDesig.toLowerCase() === 'directors') globalDesig = 'Director';
        if (globalDesig.toLowerCase() === 'owners') globalDesig = 'Owner';
        if (globalDesig.toLowerCase() === 'founders') globalDesig = 'Founder';
        desig = globalDesig;
      }

      // Phone
      let phone = cand.inlinePhone || '';
      if (!phone && phones.length > 0) {
        if (idx < phones.length) {
          phone = phones[idx];
        } else if (phones.length === 1) {
          phone = phones[0];
        }
      }

      // Email
      let email = '';
      if (allEmails.length > 0) {
        const nameParts = name.toLowerCase().split(/\s+/);
        const matchedEmail = allEmails.find((e) => {
          const prefix = e.split('@')[0].toLowerCase();
          return nameParts.some((np: string) => np.length >= 3 && prefix.includes(np));
        });
        if (matchedEmail) {
          email = matchedEmail;
        } else if (idx < allEmails.length) {
          email = allEmails[idx];
        } else {
          email = primaryEmail;
        }
      }

      detectedPersons.push({
        name,
        designation: desig,
        phone,
        email,
      });
    }

    const primaryPerson = detectedPersons.length > 0 ? detectedPersons[0] : undefined;
    const secondPerson = detectedPersons.length > 1 ? detectedPersons[1] : undefined;

    return {
      personName: primaryPerson ? primaryPerson.name : '',
      companyName,
      primaryDesignation: primaryPerson ? primaryPerson.designation : designationResult.designation,
      primaryPhone: primaryPerson?.phone || phones[0] || '',
      alternativePhone: (secondPerson?.phone && secondPerson.phone !== primaryPerson?.phone) ? secondPerson.phone : (phones.length > 1 ? phones[1] : ''),
      hasMultiplePersons: detectedPersons.length >= 2,
      detectedPersons,
    };
  }

  static cleanPersonName(raw: string): string {
    return raw
      .replace(/^(?:Name|Contact|Person)\s*[:.-]\s*/i, '')
      .replace(/[^\w\s.'-]/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static cleanCompanyName(raw: string): string {
    return raw
      .replace(/^(?:Company|Org|Organization|M\/s)\s*[:.-]\s*/i, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  static capitalizeTitle(str: string): string {
    if (!str) return '';
    return str
      .toLowerCase()
      .split(' ')
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(' ');
  }
}

export default CardParserService;
