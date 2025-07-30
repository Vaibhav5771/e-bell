const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const axios = require('axios');

const app = express();

app.use(cors());
app.use(express.json());

// Create directories on startup
const setupDirectories = async () => {
  try {
    await fs.mkdir('uploads', { recursive: true });
    await fs.mkdir('converted', { recursive: true });
    console.log('Directories created successfully');
  } catch (err) {
    console.error('Error creating directories:', err);
  }
};
setupDirectories();

app.post('/convert', async (req, res) => {
  const { audioUrl } = req.body;
  if (!audioUrl) {
    return res.status(400).send('No audio URL provided');
  }

  const inputName = `${Date.now().millisecondsSinceEpoch}.aac`;
  const inputPath = path.join('uploads', inputName);
  const outputName = `${Date.now().millisecondsSinceEpoch}.wav`;
  const outputPath = path.join('converted', outputName);

  try {
    // Download file from Firebase Storage
    const response = await axios.get(audioUrl, { responseType: 'arraybuffer' });
    await fs.writeFile(inputPath, response.data);

    // Convert with FFmpeg
    const cmd = `ffmpeg -i "${inputPath}" "${outputPath}"`;
    exec(cmd, async (error, stdout, stderr) => {
      try {
        await fs.unlink(inputPath); // Delete input file
      } catch (err) {
        console.error('Error deleting input file:', err);
      }

      if (error) {
        console.error('FFmpeg error:', stderr);
        return res.status(500).send('Conversion failed');
      }

      // Send converted file
      res.download(outputPath, outputName, async (err) => {
        if (err) {
          console.error('Download error:', err);
          return res.status(500).send('Download failed');
        }

        try {
          await fs.unlink(outputPath); // Delete output file
        } catch (err) {
          console.error('Error deleting output file:', err);
        }
      });
    });
  } catch (err) {
    console.error('Error downloading file:', err);
    return res.status(500).send('File download failed');
  }
});

app.get('/health', (req, res) => {
  res.status(200).send('Server is running');
});

const PORT = process.env.PORT || 4365;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});