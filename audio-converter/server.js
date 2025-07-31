const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');

const app = express();

app.use(cors());
app.use(express.json());

// Setup multer upload directory
const upload = multer({ dest: 'uploads/' });

// Create necessary directories
const setupDirectories = async () => {
  try {
    await fs.mkdir('uploads', { recursive: true });
    await fs.mkdir('converted', { recursive: true });
    console.log('✅ Directories created or already exist');
  } catch (err) {
    console.error('❌ Error creating directories:', err);
  }
};
setupDirectories();

// Health check route
app.get('/health', (req, res) => {
  console.log('🔍 Health check called');
  res.status(200).send('✅ Server is running');
});

// Audio conversion endpoint
app.post('/convert', upload.single('audio'), async (req, res) => {
  console.log('📥 Received POST /convert');

  if (!req.file) {
    console.error('❌ No audio file uploaded');
    return res.status(400).send('No audio file uploaded');
  }

  const inputPath = req.file.path;
  const outputName = `${Date.now()}.wav`;
  const outputPath = path.join('converted', outputName);

  console.log(`📁 Input file saved at: ${inputPath}`);
  console.log(`🔧 Converting to: ${outputPath}`);

  const cmd = `ffmpeg -y -i "${inputPath}" "${outputPath}"`;
  console.log(`🛠️ Running command: ${cmd}`);

  exec(cmd, async (error, stdout, stderr) => {
    console.log('🖨️ FFmpeg stdout:', stdout);
    console.log('⚠️ FFmpeg stderr:', stderr);

    // Delete original file
    try {
      await fs.unlink(inputPath);
      console.log(`🧹 Deleted input file: ${inputPath}`);
    } catch (err) {
      console.error('❌ Error deleting input file:', err);
    }

    if (error) {
      console.error('❌ FFmpeg conversion error:', error);
      return res.status(500).send('Conversion failed');
    }

    // Send converted file to client
    res.download(outputPath, outputName, async (err) => {
      if (err) {
        console.error('❌ Error sending file:', err);
        return res.status(500).send('Download failed');
      }

      console.log(`✅ File sent successfully: ${outputName}`);

      // Delete converted file
      try {
        await fs.unlink(outputPath);
        console.log(`🧹 Deleted converted file: ${outputPath}`);
      } catch (err) {
        console.error('❌ Error deleting output file:', err);
      }
    });
  });
});

// Start server
const PORT = process.env.PORT || 10000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
});
