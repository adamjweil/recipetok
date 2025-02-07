import * as admin from 'firebase-admin';
import * as serviceAccount from './serviceAccountKey.json';
import { exec } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount as admin.ServiceAccount),
  storageBucket: "recipetok-acc07.firebasestorage.app"
});

// Get the default bucket
const bucket = admin.storage().bucket();
// Or get a specific bucket
// const bucket = admin.storage().bucket('recipetok-acc07.firebasestorage.app');

console.log('Using bucket:', bucket.name);

// Add this interface at the top of the file
interface SignedUrls {
  [key: string]: string;
}

async function convertToHLS(inputUrl: string, sampleNumber: number) {
  const tempDir = path.join(__dirname, `temp/sample${sampleNumber}`);
  const outputDir = path.join(tempDir, 'output');
  
  // Create temp directories
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Download MP4
  const inputPath = path.join(tempDir, 'input.mp4');
  console.log(`Downloading ${inputUrl}...`);
  await execAsync(`curl "${inputUrl}" -o "${inputPath}"`);

  // Convert to HLS with multiple qualities
  console.log('Converting to HLS...');
  const ffmpegCommand = `
    ffmpeg -i "${inputPath}" \
    -filter_complex "[0:v]split=2[v1][v2]; \
    [v1]scale=w=1280:h=720[v1out]; \
    [v2]scale=w=854:h=480[v2out]" \
    -map "[v1out]" -map 0:a -c:v h264 -c:a aac -b:v 2800k -b:a 128k \
    -hls_time 10 -hls_list_size 0 -hls_segment_filename "${outputDir}/720p_%03d.ts" \
    -var_stream_map "v:0,a:0" "${outputDir}/720p.m3u8" \
    -map "[v2out]" -map 0:a -c:v h264 -c:a aac -b:v 1400k -b:a 128k \
    -hls_time 10 -hls_list_size 0 -hls_segment_filename "${outputDir}/480p_%03d.ts" \
    -var_stream_map "v:0,a:0" "${outputDir}/480p.m3u8"
  `;

  await execAsync(ffmpegCommand);

  // Initialize signedUrls with proper typing
  const signedUrls: SignedUrls = {};
  
  const files = fs.readdirSync(outputDir);
  for (const file of files) {
    if (file.endsWith('.m3u8')) {
      const filePath = path.join(outputDir, file);
      const destination = `videos/sample${sampleNumber}/${file}`;
      
      const [uploadedFile] = await bucket.upload(filePath, {
        destination: destination,
        metadata: {
          contentType: file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T'
        }
      });

      // Generate a signed URL with a long expiration
      const [signedUrl] = await uploadedFile.getSignedUrl({
        action: 'read',
        expires: '2100-01-01', // Far future date
      });
      
      if (file === 'playlist.m3u8') {
        console.log('Master playlist URL:', signedUrl);
      }
      signedUrls[file] = signedUrl;
    }
  }

  const masterPlaylist = `
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=2928000,RESOLUTION=1280x720
${signedUrls['720p.m3u8']}
#EXT-X-STREAM-INF:BANDWIDTH=1528000,RESOLUTION=854x480
${signedUrls['480p.m3u8']}
  `.trim();

  fs.writeFileSync(path.join(outputDir, 'playlist.m3u8'), masterPlaylist);

  // Upload to Firebase Storage
  console.log('Uploading to Firebase Storage...');
  const filesToUpload = fs.readdirSync(outputDir).filter(file => !file.endsWith('.m3u8'));
  const uploadedFiles = [];
  for (const file of filesToUpload) {
    const filePath = path.join(outputDir, file);
    const destination = `videos/sample${sampleNumber}/${file}`;
    
    const [uploadedFile] = await bucket.upload(filePath, {
      destination: destination,
      metadata: {
        contentType: file.endsWith('.m3u8') ? 'application/x-mpegURL' : 'video/MP2T'
      }
    });

    // Generate a signed URL with a long expiration
    const [signedUrl] = await uploadedFile.getSignedUrl({
      action: 'read',
      expires: '2100-01-01', // Far future date
    });
    
    if (file === 'playlist.m3u8') {
      console.log('Master playlist URL:', signedUrl);
    }
    uploadedFiles.push(signedUrl);
  }

  // Cleanup
  fs.rmSync(tempDir, { recursive: true, force: true });
  
  console.log(`Completed sample${sampleNumber}`);
}

async function main() {
  const videos = [
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
    // 'https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    // 'https://storage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    // 'https://storage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
    // 'https://storage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    // 'https://storage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4'
  ];

  for (let i = 0; i < videos.length; i++) {
    await convertToHLS(videos[i], i + 1);
  }

  console.log('All conversions complete!');

  // Add this to convert-to-hls.ts to get the download URL
  const [downloadUrl] = await bucket.file('videos/sample1/playlist.m3u8').getSignedUrl({
    action: 'read',
    expires: '03-01-2500'
  });
  console.log('Download URL:', downloadUrl);

  process.exit(0);
}

main().catch(console.error); 