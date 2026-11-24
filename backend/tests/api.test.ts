import http from 'http';
import assert from 'assert';
import dotenv from 'dotenv';

process.env.NODE_ENV = 'test';
dotenv.config({ path: __dirname + '/../.env' });

import { app } from '../src/server';

const TEST_PORT = 5055;
const server = app.listen(TEST_PORT);

function request(options: http.RequestOptions, bodyData?: any): Promise<{ status: number; headers: any; body: any }> {
  return new Promise((resolve, reject) => {
    options.port = TEST_PORT;
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        let json;
        try {
          json = JSON.parse(data);
        } catch (e) {
          json = data;
        }
        resolve({ status: res.statusCode || 500, headers: res.headers, body: json });
      });
    });

    req.on('error', reject);

    if (bodyData) {
      req.write(typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData));
    }
    req.end();
  });
}

async function runTests() {
  console.log('\n--- STARTING TYPESCRIPT BACKEND REST API END-TO-END TESTS ---\n');

  await new Promise((r) => setTimeout(r, 2000));

  let token = '';
  let contactId = '';
  const testEmail = `testuser_ts_${Date.now()}@example.com`;

  try {
    // 1. Health Check
    console.log('1. Testing GET /api/health...');
    const healthRes = await request({
      hostname: 'localhost',
      path: '/api/health',
      method: 'GET',
    });
    assert.strictEqual(healthRes.status, 200);
    assert.strictEqual(healthRes.body.status, 'ok');
    assert.strictEqual(healthRes.body.storage, 'AWS S3');
    console.log('✓ Health check passed (AWS S3 verified)');

    // 2. User Registration
    console.log('2. Testing POST /api/auth/register...');
    const regRes = await request(
      {
        hostname: 'localhost',
        path: '/api/auth/register',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      {
        name: 'Alexander Pierce',
        email: testEmail,
        mobile: '+919988776655',
        password: 'Password123!',
      }
    );
    assert.strictEqual(regRes.status, 201);
    assert.ok(regRes.body.token, 'Should receive JWT token');
    token = regRes.body.token;
    console.log('✓ User registration passed with token');

    // 3. User Login
    console.log('3. Testing POST /api/auth/login...');
    const loginRes = await request(
      {
        hostname: 'localhost',
        path: '/api/auth/login',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
      {
        email: testEmail,
        password: 'Password123!',
      }
    );
    assert.strictEqual(loginRes.status, 200);
    assert.ok(loginRes.body.token);
    console.log('✓ User login passed');

    // 4. Test S3 Presigned URL Endpoint (No Multer)
    console.log('4. Testing POST /api/cards/presigned-url...');
    const presignedRes = await request(
      {
        hostname: 'localhost',
        path: '/api/cards/presigned-url',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      },
      { fileName: 'business_card.jpg', mimeType: 'image/jpeg' }
    );
    assert.strictEqual(presignedRes.status, 200);
    assert.ok(presignedRes.body.presignedUrl);
    assert.ok(presignedRes.body.key);
    assert.ok(presignedRes.body.publicUrl.includes('dhrumiiil.s3.ap-south-1.amazonaws.com'));
    console.log('✓ AWS S3 Presigned URL generated successfully');

    // 5. Test OCR Extraction Endpoint
    console.log('5. Testing POST /api/cards/extract...');
    const sampleRawText = `
GLOBAL METRICS TECHNOLOGIES PVT LTD
Vikram Aditya Singh
Vice President - Engineering
Mobile: +91 91234 56789
Alt: 022 2847 1122
Email: vikram.singh@globalmetrics.com
Web: https://www.globalmetrics.com
GSTIN: 27AABCG1234F1Z9
BKC Bandra East, Mumbai, Maharashtra 400051
`;
    const extractRes = await request(
      {
        hostname: 'localhost',
        path: '/api/cards/extract',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      },
      { rawText: sampleRawText }
    );
    assert.strictEqual(extractRes.status, 200);
    assert.strictEqual(extractRes.body.data.personName, 'Vikram Aditya Singh');
    assert.strictEqual(extractRes.body.data.email, 'vikram.singh@globalmetrics.com');
    assert.strictEqual(extractRes.body.data.gstNumber, '27AABCG1234F1Z9');
    console.log('✓ Intelligent OCR extraction endpoint verified');

    // 6. Create Contact Endpoint
    console.log('6. Testing POST /api/contacts...');
    const createRes = await request(
      {
        hostname: 'localhost',
        path: '/api/contacts',
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      },
      {
        personName: extractRes.body.data.personName,
        companyName: extractRes.body.data.companyName,
        designation: extractRes.body.data.designation,
        phone: extractRes.body.data.phone,
        alternativePhone: extractRes.body.data.alternativePhone,
        email: extractRes.body.data.email,
        website: extractRes.body.data.website,
        address: extractRes.body.data.address,
        city: extractRes.body.data.city,
        state: extractRes.body.data.state,
        country: extractRes.body.data.country,
        gstNumber: extractRes.body.data.gstNumber,
      }
    );
    assert.strictEqual(createRes.status, 201);
    assert.ok(createRes.body.contact._id);
    contactId = createRes.body.contact._id;
    console.log(`✓ Contact created with ID: ${contactId}`);

    // 7. Get All Contacts (with Search)
    console.log('7. Testing GET /api/contacts (search)...');
    const listRes = await request({
      hostname: 'localhost',
      path: '/api/contacts?search=Vikram',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    assert.strictEqual(listRes.status, 200);
    assert.strictEqual(listRes.body.contacts.length, 1);
    assert.strictEqual(listRes.body.contacts[0].personName, 'Vikram Aditya Singh');
    console.log('✓ Contact listing and search verified');

    // 8. Update Contact
    console.log('8. Testing PUT /api/contacts/:id...');
    const updateRes = await request(
      {
        hostname: 'localhost',
        path: `/api/contacts/${contactId}`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
      },
      {
        notes: 'Updated contact notes in TypeScript backend',
      }
    );
    assert.strictEqual(updateRes.status, 200);
    assert.strictEqual(updateRes.body.contact.notes, 'Updated contact notes in TypeScript backend');
    console.log('✓ Contact update verified');

    // 9. Dashboard Stats
    console.log('9. Testing GET /api/dashboard/stats...');
    const statsRes = await request({
      hostname: 'localhost',
      path: '/api/dashboard/stats',
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    assert.strictEqual(statsRes.status, 200);
    assert.ok(statsRes.body.stats.totalContacts >= 1);
    console.log('✓ Dashboard stats verified');

    // 10. Export VCF
    console.log('10. Testing GET /api/contacts/:id/vcf...');
    const vcfRes = await request({
      hostname: 'localhost',
      path: `/api/contacts/${contactId}/vcf`,
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    assert.strictEqual(vcfRes.status, 200);
    assert.ok(vcfRes.body.includes('BEGIN:VCARD'));
    assert.ok(vcfRes.body.includes('FN:Vikram Aditya Singh'));
    console.log('✓ VCF export endpoint verified');

    // 11. Delete Contact
    console.log('11. Testing DELETE /api/contacts/:id...');
    const delRes = await request({
      hostname: 'localhost',
      path: `/api/contacts/${contactId}`,
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    assert.strictEqual(delRes.status, 200);
    console.log('✓ Contact deleted verified');

    console.log('\n======================================================');
    console.log('🌟 ALL 11 TYPESCRIPT & AWS S3 TESTS PASSED! 🌟');
    console.log('======================================================\n');
  } catch (err) {
    console.error('❌ Test failed:', err);
    process.exitCode = 1;
  } finally {
    server.close();
    process.exit(process.exitCode || 0);
  }
}

runTests();
