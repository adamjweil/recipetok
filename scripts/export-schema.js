const admin = require('firebase-admin');
const serviceAccount = require('../lib/config/service-account.json');
const fs = require('fs');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://tiktok-d4955-default-rtdb.firebaseio.com/"
});

function inferFieldType(entries) {
  // Get a few sample entries to better infer the type
  const samples = Object.values(entries).slice(0, 3);
  
  // If all samples are objects with similar structure, it's likely a collection
  if (samples.every(s => typeof s === 'object')) {
    return "object";
  }
  
  // If all samples are booleans, it's likely a flag/boolean field
  if (samples.every(s => typeof s === 'boolean')) {
    return "boolean";
  }
  
  // If all samples are numbers, it's a number field
  if (samples.every(s => typeof s === 'number')) {
    return "number";
  }
  
  // Default to string for other cases
  return "string";
}

function extractTableSchema(data) {
  const schema = {};
  
  for (const tableName in data) {
    const tableData = data[tableName];
    schema[tableName] = {
      fields: {},
      relationships: []
    };

    // If the table has entries
    if (tableData && typeof tableData === 'object') {
      // Get a sample entry
      const sampleEntry = Object.values(tableData)[0];
      
      if (sampleEntry && typeof sampleEntry === 'object') {
        // For each field in the sample entry
        for (const field in sampleEntry) {
          // Skip UUID-like fields
          if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(field) &&
              !/^[A-Za-z0-9]{20,}$/.test(field)) {
            schema[tableName].fields[field] = inferFieldType(sampleEntry);
          }
        }
      } else {
        // If the entries themselves are primitive values
        schema[tableName].fields = {
          value: inferFieldType(tableData)
        };
      }
    }

    // Add relationships based on field names
    if (schema[tableName].fields.userId) {
      schema[tableName].relationships.push({
        field: "userId",
        type: "one-to-one",
        relatedTo: "user"
      });
    }
  }
  
  return schema;
}

async function exportTableSchema() {
  try {
    console.log('Fetching database structure...');
    const db = admin.database();
    const snapshot = await db.ref('/').once('value');
    const data = snapshot.val();
    
    console.log('Analyzing table structure...');
    const schema = extractTableSchema(data);
    
    fs.writeFileSync('table-schema.json', JSON.stringify(schema, null, 2));
    console.log('Table schema exported successfully!');
  } catch (error) {
    console.error('Error during export:', error);
  }
}

exportTableSchema().catch(console.error);