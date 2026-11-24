export class VcfService {
  /**
   * Convert Contact document or object to vCard 3.0 string
   */
  static generateVCard(contact: any): string {
    const lines = [
      'BEGIN:VCARD',
      'VERSION:3.0',
    ];

    const fullName = contact.personName || 'Unnamed Contact';
    lines.push(`FN:${this.escape(fullName)}`);

    const nameParts = fullName.split(' ');
    const givenName = nameParts[0] || '';
    const familyName = nameParts.length > 1 ? nameParts.slice(1).join(' ') : '';
    lines.push(`N:${this.escape(familyName)};${this.escape(givenName)};;;`);

    if (contact.companyName) {
      lines.push(`ORG:${this.escape(contact.companyName)}`);
    }

    if (contact.designation) {
      lines.push(`TITLE:${this.escape(contact.designation)}`);
    }

    if (contact.phone) {
      lines.push(`TEL;TYPE=CELL,VOICE:${contact.phone}`);
    }
    if (contact.alternativePhone) {
      lines.push(`TEL;TYPE=WORK,VOICE:${contact.alternativePhone}`);
    }

    if (contact.email) {
      lines.push(`EMAIL;TYPE=WORK,INTERNET:${contact.email}`);
    }

    if (contact.website) {
      lines.push(`URL:${contact.website}`);
    }

    if (contact.address || contact.city || contact.state || contact.country) {
      const street = this.escape(contact.address || '');
      const locality = this.escape(contact.city || '');
      const region = this.escape(contact.state || '');
      const country = this.escape(contact.country || 'India');
      lines.push(`ADR;TYPE=WORK:;;${street};${locality};${region};;${country}`);
    }

    const noteParts: string[] = [];
    if (contact.gstNumber) noteParts.push(`GST: ${contact.gstNumber}`);
    if (contact.category) noteParts.push(`Category: ${contact.category}`);
    if (contact.notes) noteParts.push(contact.notes);

    if (noteParts.length > 0) {
      lines.push(`NOTE:${this.escape(noteParts.join(' | '))}`);
    }

    lines.push('REV:' + new Date().toISOString());
    lines.push('END:VCARD');

    return lines.join('\r\n');
  }

  static escape(text: string): string {
    if (!text) return '';
    return text
      .replace(/\\/g, '\\\\')
      .replace(/;/g, '\\;')
      .replace(/,/g, '\\,')
      .replace(/\n/g, '\\n');
  }
}

export default VcfService;
