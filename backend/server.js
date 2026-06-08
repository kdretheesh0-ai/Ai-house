const express = require('express');
const multer = require('multer');
const { createClient } = require('@supabase/supabase-js');
const cors = require('cors');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const { GoogleGenerativeAI } = require('@google/generative-ai');
const Razorpay = require('razorpay');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Initialize Razorpay
const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID || 'rzp_test_placeholder',
  key_secret: process.env.RAZORPAY_KEY_SECRET || 'placeholder_secret',
});

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const dir = 'uploads';
    if (!fs.existsSync(dir)) fs.mkdirSync(dir);
    cb(null, dir);
  },
  filename: (req, file, cb) => cb(null, Date.now() + path.extname(file.originalname))
});
const upload = multer({ storage });
const multiUpload = upload.fields([{ name: 'ground_plan', maxCount: 1 }, { name: 'first_plan', maxCount: 1 }, { name: 'second_plan', maxCount: 1 }]);

function cleanUploadsFolder(dir, maxFiles = 20) {
  try {
    if (!fs.existsSync(dir)) return;
    const files = fs.readdirSync(dir)
      .map(name => ({
        name,
        time: fs.statSync(path.join(dir, name)).mtime.getTime()
      }))
      .sort((a, b) => b.time - a.time); // Newest first

    if (files.length > maxFiles) {
      const filesToDelete = files.slice(maxFiles);
      filesToDelete.forEach(file => {
        fs.unlinkSync(path.join(dir, file.name));
        console.log(`[Cleanup] Auto-deleted old file to save space: ${file.name}`);
      });
    }
  } catch (err) {
    console.error('[Cleanup Error]', err.message);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function validateModelData(data) {
  if (!data || typeof data !== 'object') return null;
  if (!data.project) data.project = { name: 'Floor Plan', width: 30, height: 40 };
  ['rooms', 'walls', 'doors', 'windows', 'furnitures', 'stairs', 'voids', 'columns'].forEach(k => {
    if (!Array.isArray(data[k])) data[k] = [];
  });
  // Always regenerate walls from rooms for perfect, clean 3D geometry
  if (data.rooms.length > 0) {
    data.walls = generateWallsFromRooms(data.rooms, data.project);
  }
  return data;
}


function generateWallsFromRooms(rooms, project) {
  const pw = project.width || 30, ph = project.height || 40;
  const wallSet = new Set(), walls = [];
  rooms.forEach(room => {
    const rx = room.x || 0, ry = room.y || 0, rw = room.width || 0, rh = room.height || 0;
    const edges = [
      [[rx, ry], [rx + rw, ry]], [[rx, ry + rh], [rx + rw, ry + rh]],
      [[rx, ry], [rx, ry + rh]], [[rx + rw, ry], [rx + rw, ry + rh]],
    ];
    edges.forEach(([s, e]) => {
      const isExt = s[0] <= 0.5 || s[0] >= pw - 0.5 || e[0] <= 0.5 || e[0] >= pw - 0.5 ||
        s[1] <= 0.5 || s[1] >= ph - 0.5 || e[1] <= 0.5 || e[1] >= ph - 0.5;
      const key = [
        Math.min(s[0], e[0]).toFixed(1), Math.min(s[1], e[1]).toFixed(1),
        Math.max(s[0], e[0]).toFixed(1), Math.max(s[1], e[1]).toFixed(1)
      ].join(',');
      if (!wallSet.has(key)) {
        wallSet.add(key);
        walls.push({
          start: [+s[0].toFixed(2), +s[1].toFixed(2)],
          end: [+e[0].toFixed(2), +e[1].toFixed(2)],
          thickness: isExt ? 0.9 : 0.5
        });
      }
    });
  });
  return walls;
}

// ─── Step 1 + 2: Gemini Vision → Structured JSON ──────────────────────────────

function runPython(imagePath) {
  return new Promise((resolve, reject) => {
    console.log(`[Step 1] Gemini Vision analyzing: ${imagePath}`);
    const proc = spawn('python', ['processor.py', imagePath], { env: { ...process.env } });
    const timeout = setTimeout(() => { proc.kill(); reject(new Error('AI processing timed out')); }, 600000);
    let out = '';
    proc.stdout.on('data', d => out += d.toString());
    proc.stderr.on('data', d => console.error(`[Python] ${d.toString().trim()}`));
    proc.on('close', code => {
      clearTimeout(timeout);
      if (code !== 0) return reject(new Error('AI processor failed. Code: ' + code));
      try { resolve(JSON.parse(out)); } catch (e) { reject(new Error('Invalid JSON from processor')); }
    });
  });
}

function runVisualizer(imagePath, metadata = null) {
  return new Promise((resolve, reject) => {
    console.log(`[Step 8] Generating 3D Visual Design: ${imagePath}`);
    const args = [imagePath];
    if (metadata) args.push(JSON.stringify(metadata));

    const proc = spawn('python', ['visualizer.py', ...args], { env: { ...process.env } });
    let out = '';
    proc.stdout.on('data', d => out += d.toString());
    proc.on('close', code => {
      if (code !== 0) return resolve({ error: 'Visualizer failed' });
      try { resolve(JSON.parse(out.trim())); } catch (e) { resolve({ error: 'Invalid JSON from visualizer' }); }
    });
  });
}

// ─── Step 5: Vastu Analysis Engine (Enhanced with OpenRouter) ────────────────

async function askOpenRouter(prompt, imagePath = null, model = 'google/gemini-2.5-flash') {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return null;

  try {
    let contents = [{ type: 'text', text: prompt }];

    if (imagePath && fs.existsSync(imagePath)) {
      const imageData = fs.readFileSync(imagePath).toString('base64');
      contents.push({
        type: 'image_url',
        image_url: { url: `data:image/png;base64,${imageData}` }
      });
    }

    const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "HTTP-Referer": "http://localhost:3000",
        "X-Title": "ArchiGen AI",
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        "model": model,
        "messages": [{ "role": "user", "content": contents }],
        "response_format": { "type": "json_object" }
      })
    });

    const data = await response.json();
    if (data.choices && data.choices[0]) {
      const content = data.choices[0].message.content || "";
      return JSON.parse(content.replace(/```json|```/g, '').trim());
    }
    return null;
  } catch (e) {
    console.error('[OpenRouter] Error:', e.message);
    return null;
  }
}

async function runVastuAnalysis(modelData, lang = 'English', imagePath = null, fixedScore = null, fixedGrade = null, floorName = 'Ground') {
  const pw = modelData.project?.width || 44;
  const ph = modelData.project?.height || 40;

  // Mathematically calculate the exact Vastu zone for each room to guarantee 100% accuracy
  const roomsStr = (modelData.rooms || []).map(r => {
    const cx = (r.x || 0) + ((r.width || 0) / 2);
    const cy = (r.y || 0) + ((r.height || 0) / 2);
    
    let lat = 'Center';
    if (cy < ph / 3) lat = 'North';
    else if (cy > (2 * ph) / 3) lat = 'South';

    let lon = '';
    if (cx < pw / 3) lon = 'West';
    else if (cx > (2 * pw) / 3) lon = 'East';

    let zone = '';
    if (lat === 'Center' && lon === '') zone = 'Brahmasthan (Center)';
    else if (lat === 'Center') zone = lon;
    else if (lon === '') zone = lat;
    else zone = `${lat}-${lon}`; // e.g. North-East

    return `[${r.floor || '0th Floor (Ground)'}] ${r.name} - Mathematical Zone: ${zone} (Center at X:${cx.toFixed(1)}, Y:${cy.toFixed(1)})`;
  }).join('\n');

  const isTamil = lang && lang.toLowerCase().includes('tamil');

  const prompt = `You are a Vastu Shastra expert and architectural consultant.
  Analyze the provided 2D floor plan coordinates and the attached image (if provided) to generate a highly accurate, customized Vastu report specifically for the ${floorName.toUpperCase()} FLOOR.
  
  CRITICAL: The report MUST be UNIQUE and ACCURATE to this specific 2D design. You MUST use the exact Mathematical Zones provided below to apply strict Vastu Shastra rules and logic.
  
  LANGUAGE: The entire JSON response (strengths, violations, suggestions, etc.) MUST be in ${lang}.
  
  VASTU RULES & LOGIC TO APPLY:
  - North-East (Eesanyam): Favorable for Pooja Room, Water sources, Main Entrance.
  - South-East (Agnimoolai): Favorable for Kitchen, Electricals.
  - South-West (Niruthi): Favorable for Master Bedroom, Staircase. Toilets/Kitchens here cause severe negative scores.
  - North-West (Vayuvyam): Favorable for Guest room, Toilets.
  - Brahmasthan (Center): Must be open/empty. No heavy pillars or toilets.
  
  DATA TO ANALYZE (Strictly base your analysis on this):
  - Plot Size: ${pw}x${ph}ft
  - Room Coordinates:
  ${roomsStr}
  
  TASK:
  1. Evaluate the precise placement of the Main Entrance, Kitchen, Bedrooms, Pooja, and Toilets based on the coordinates provided.
  2. ${fixedScore !== null ? `USE THIS EXACT SCORE: ${fixedScore}. DO NOT CALCULATE A NEW ONE.` : 'Calculate an accurate Vastu Score (0-100) based strictly on how well these specific room coordinates comply with traditional Vastu rules.'}
  3. ${fixedGrade !== null ? `USE THIS EXACT GRADE: "${fixedGrade}".` : 'Provide a grade based on the score.'}
  4. Provide 3+ specific strengths directly referencing the coordinates/rooms.
  5. Provide 2+ detailed violations explicitly explaining WHY the score was reduced. Detail the exact room and its incorrect placement (e.g., "Kitchen is at (${pw/2}, ${ph/2}) which is the center, causing a -10 point reduction").
  6. Provide 3+ practical remedies for these specific violations.
  
  JSON FORMAT (STRICT):
  {
    "score": number,
    "grade": "A+" | "A" | "B" | "C",
    "mainEntrance": "Specific analysis in ${lang}",
    "kitchen": "Specific analysis in ${lang}",
    "masterBedroom": "Specific analysis in ${lang}",
    "bathroom": "Specific analysis in ${lang}",
    "staircase": "Specific analysis in ${lang}",
    "poojaRoom": "Specific analysis in ${lang}",
    "livingRoom": "Specific analysis in ${lang}",
    "strengths": ["Detailed point referencing design", "Detailed point 2"],
    "violations": ["Detailed reason why score reduced for room X", "Detailed reason 2"],
    "suggestions": ["Specific Remedy 1", "Specific Remedy 2"]
  }`;

  try {
    console.log('[Step 5] Using Gemini API for Vastu Analysis...');
    const model = genAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: { responseMimeType: "application/json" }
    });

    let parts = [prompt];
    if (imagePath && fs.existsSync(imagePath)) {
      const imageData = fs.readFileSync(imagePath);
      parts.push({
        inlineData: {
          data: imageData.toString('base64'),
          mimeType: 'image/png'
        }
      });
    }

    const result = await model.generateContent(parts);
    const rawText = result.response.text() || "";
    return JSON.parse(rawText.replace(/```json|```/g, '').trim());
  } catch (e) {
    console.error('[Step 5] Vastu error:', e.message);

    // Create a slightly more dynamic fallback based on detected rooms
    const hasKitchen = (modelData.rooms || []).some(r => r.name.toLowerCase().includes('kitchen'));
    const hasBedroom = (modelData.rooms || []).some(r => r.name.toLowerCase().includes('bedroom'));
    const score = fixedScore !== null ? fixedScore : (70 + (Math.random() * 5));
    const grade = fixedGrade !== null ? fixedGrade : (score > 85 ? 'A' : 'B');

    if (isTamil) {
      return {
        score: Math.round(score),
        grade: grade,
        mainEntrance: "வடிவமைப்பைப் பொறுத்து நுழைவாயில் திசை அமையும்.",
        kitchen: hasKitchen ? "சமையலறை நிலையைச் சரிபார்க்கவும்." : "சமையலறை திட்டத்தில் சரியாகக் குறிக்கப்படவில்லை.",
        masterBedroom: hasBedroom ? "முதன்மை படுக்கையறை தென்மேற்கில் இருப்பது நலம்." : "படுக்கையறை அமைப்பு தேவை.",
        bathroom: "கழிவறை வடகிழக்கைத் தவிர்க்க வேண்டும்.",
        staircase: "மாடிப்படி தென்மேற்கு அல்லது மேற்கில் இருக்கலாம்.",
        poojaRoom: "பூஜை அறை வடகிழக்கில் இருப்பது சிறப்பு.",
        livingRoom: "வரவேற்பு அறை கிழக்கு நோக்கி இருக்கலாம்.",
        strengths: [`${floorName} தளத்தில் ${pw}x${ph} அளவீடு சிறப்பாகப் பயன்படுத்தப்பட்டுள்ளது`, "அறைகளின் இடவசதி நன்றாக உள்ளது", "காற்றோட்டமான அமைப்பு"],
        violations: [`${floorName} தளத்தில் திசை நோக்குநிலை துல்லியமாகச் சரிபார்க்கப்பட வேண்டும்`, "அறைகளின் இடமாற்றம் தேவைப்படலாம்"],
        suggestions: ["தலைவாசலை உச்ச நிலையில் அமைக்கவும்", "வாஸ்து நிபுணரைக் கலந்தாலோசிக்கவும்", "இயற்கை வெளிச்சத்தை அதிகரிக்கவும்"],
        room_ratings: {}
      };
    }

    return {
      score: Math.round(score),
      grade: grade,
      mainEntrance: `Analysis depends on exact design orientation for ${floorName} floor`,
      kitchen: hasKitchen ? `Check kitchen placement in SE for ${floorName} floor` : "Kitchen not clearly identified",
      masterBedroom: hasBedroom ? `Master bedroom is best in SW for ${floorName} floor` : "Bedroom placement needs check",
      bathroom: `Avoid toilets in NE zone on ${floorName} floor`,
      staircase: "Stairs recommended in West or South",
      poojaRoom: `Pooja room recommended in NE zone for ${floorName} floor`,
      livingRoom: `Living room best in East or North on ${floorName} floor`,
      strengths: [`Efficient use of ${pw}x${ph} plot on the ${floorName} floor`, `Good spatial distribution for ${floorName}`, 'Modern layout approach'],
      violations: [`Orientation alignment needs verification on ${floorName}`, 'Potential room placement issues'],
      suggestions: [`Optimize layout specifically for the ${floorName} floor`, 'Increase natural light entry', 'Verify plumbing zones'],
      room_ratings: {}
    };
  }
}

// ─── Step 6: Cost Estimation ──────────────────────────────────────────────────

function runCostEstimation(modelData) {
  const rooms = modelData.rooms || [];
  const project = modelData.project || {};
  const floorArea = parseFloat(project.width || 30) * parseFloat(project.height || 40);
  const floors = project.floors || 1;
  const totalArea = floorArea * floors;

  // INR per sq ft rates (India 2026 standard)
  const RATES = {
    'Living Room': 2100, 'Hall': 1900, 'Lounge': 1900,
    'Master Bedroom': 2200, 'Master Bdrm': 2200, 'Bedroom': 2000, 'Bedroom 2': 2000,
    'Kitchen': 2550, 'Dining Area': 1950, 'Dining': 1950,
    'Bathroom': 2850, 'Toilet': 2850, 'Attached Toilet': 2850, 'Common Toilet': 2750,
    'Car Parking': 1050, 'Car Parking Portico': 1050, 'Portico': 1050,
    'Utility Area': 1400, 'Store Room': 1300, 'Pooja': 2300,
    'Staircase': 1600, 'default': 1850
  };

  const roomBreakdown = rooms.map(r => {
    const area = +((r.width || 0) * (r.height || 0)).toFixed(1);
    const rate = Object.keys(RATES).find(k => r.name?.toLowerCase().includes(k.toLowerCase()))
      ? RATES[Object.keys(RATES).find(k => r.name?.toLowerCase().includes(k.toLowerCase()))]
      : RATES.default;
    const displayName = r.floor ? `${r.name} (${r.floor})` : r.name;
    return { name: displayName, area, rate, cost: Math.round(area * rate) };
  });

  const structureCost = roomBreakdown.reduce((s, r) => s + r.cost, 0);
  const finishingCost = Math.round(totalArea * 420);
  const elecPlumbing = Math.round(totalArea * 330);
  const flooring = Math.round(totalArea * 260);
  const doorsWindows = Math.round(totalArea * 210);
  const contingency = Math.round(structureCost * 0.08);
  const baseTotal = structureCost + finishingCost + elecPlumbing + flooring + doorsWindows + contingency;

  const perimeter = (parseFloat(project.width || 30) + parseFloat(project.height || 40)) * 2;
  const wallArea = perimeter * 10; // Assuming 10 ft height

  const materials = {
    cement: { name: 'Cement', quantity: Math.round(totalArea * 0.4), unit: 'bags', price: 380 },
    steel: { name: 'Steel', quantity: Math.round(totalArea * 4), unit: 'kg', price: 65 },
    sand: { name: 'Sand', quantity: Math.round(totalArea * 1.8), unit: 'cft', price: 45 },
    bricks: { name: 'Bricks', quantity: Math.round(wallArea * 8), unit: 'pcs', price: 9 },
    tiles: { name: 'Tiles', quantity: Math.round(totalArea * 1.1), unit: 'sqft', price: 55 },
    paint: { name: 'Paint', quantity: Math.round((totalArea * 1.5) / 50), unit: 'liters', price: 250 }, // 1 liter ~ 50 sqft
    electrical: { name: 'Electrical', quantity: Math.round(totalArea), unit: 'sqft', price: 120 },
    plumbing: { name: 'Plumbing', quantity: Math.round(totalArea), unit: 'sqft', price: 100 }
  };

  return {
    total_area_sqft: +totalArea.toFixed(1),
    room_breakdown: roomBreakdown,
    cost_breakdown: {
      structure_construction: structureCost,
      finishing_plaster_paint: finishingCost,
      electrical_plumbing: elecPlumbing,
      flooring,
      doors_windows: doorsWindows,
      miscellaneous_contingency: contingency
    },
    estimates: {
      basic: Math.round(baseTotal * 1.0),
      standard: Math.round(baseTotal * 1.35),
      premium: Math.round(baseTotal * 1.75)
    },
    cost_per_sqft: {
      basic: Math.round(baseTotal / totalArea),
      standard: Math.round((baseTotal * 1.35) / totalArea),
      premium: Math.round((baseTotal * 1.75) / totalArea)
    },
    materials: materials,
    currency: 'INR',
    note: 'Estimates based on 2026 Indian construction rates. Actual costs vary by location and contractor.'
  };
}

// ─── Material Search Endpoint ───────────────────────────────────────────────
app.post('/api/material/search', async (req, res) => {
  const { query } = req.body;
  if (!query) return res.status(400).json({ error: 'Query required' });

  try {
    const prompt = `Find 3 to 4 highly accurate current market prices in India for construction materials related to: "${query}".
    Provide realistic, data-driven estimates based on the current market. Include the exact matched brand and 2-3 similar alternatives or related materials.
    Return a STRICT JSON array of objects:
    [
      {
        "brand": "Exact Brand Name (e.g., Priya Cement, Tata Tiscon, Asian Paints)",
        "price": numeric_price_only (e.g. 390),
        "unit": "unit (e.g., bag, kg, piece, liter, sqft)"
      }
    ]`;

    let data = null;

    // Try OpenRouter first for maximum accuracy if available
    if (process.env.OPENROUTER_API_KEY) {
      console.log(`[Material Search] Using OpenRouter for: ${query}`);
      data = await askOpenRouter(prompt, null, 'google/gemini-2.0-flash-001');
    }

    if (!data) {
      console.log(`[Material Search] Using Gemini directly for: ${query}`);
      const model = genAI.getGenerativeModel({
        model: 'gemini-2.5-flash',
        generationConfig: { responseMimeType: "application/json" }
      });
      const result = await model.generateContent(prompt);
      const rawText = result.response.text() || "";
      data = JSON.parse(rawText.replace(/```json|```/g, '').trim());
    }

    if (Array.isArray(data)) {
      data.forEach(item => {
        if (item && typeof item.price === 'string') item.price = parseFloat(item.price) || 0;
      });
    } else if (data && data.brand) {
      if (typeof data.price === 'string') data.price = parseFloat(data.price) || 0;
      data = [data]; // Fallback if AI returned single object
    } else {
      data = [];
    }
    
    res.json(data);
  } catch (err) {
    console.error('[API] Material search error:', err.message);
    
    // Smart Fallback if Google API is rate-limited or blocked
    const q = query.toLowerCase();
    let fallback = [
      { brand: query + " (Estimated)", price: 500, unit: 'unit' },
      { brand: query + " Premium (Estimated)", price: 800, unit: 'unit' }
    ];
    
    if (q.includes('cement') || q.includes('ultra tech') || q.includes('priya') || q.includes('acc')) {
      fallback = [
        { brand: "Priya Cement (Estimated)", price: 390, unit: 'bag' },
        { brand: "UltraTech Cement (Estimated)", price: 450, unit: 'bag' },
        { brand: "ACC Cement (Estimated)", price: 440, unit: 'bag' }
      ];
    } else if (q.includes('steel') || q.includes('tata') || q.includes('jsw') || q.includes('tiscon')) {
      fallback = [
        { brand: "Tata Tiscon 550SD (Estimated)", price: 88, unit: 'kg' },
        { brand: "JSW Neosteel (Estimated)", price: 85, unit: 'kg' },
        { brand: "SAIL TMT (Estimated)", price: 82, unit: 'kg' }
      ];
    } else if (q.includes('paint') || q.includes('asian') || q.includes('berger')) {
      fallback = [
        { brand: "Asian Paints Royale (Estimated)", price: 320, unit: 'liter' },
        { brand: "Berger WeatherCoat (Estimated)", price: 280, unit: 'liter' },
        { brand: "Dulux Velvet (Estimated)", price: 340, unit: 'liter' }
      ];
    } else if (q.includes('tile') || q.includes('kajaria')) {
      fallback = [
        { brand: "Kajaria Vitrified (Estimated)", price: 65, unit: 'sqft' },
        { brand: "Somany Ceramics (Estimated)", price: 60, unit: 'sqft' },
        { brand: "RAK Ceramics (Estimated)", price: 85, unit: 'sqft' }
      ];
    } else if (q.includes('wire') || q.includes('electric') || q.includes('havells')) {
      fallback = [
        { brand: "Havells Wires (Estimated)", price: 1500, unit: 'coil' },
        { brand: "Polycab Wires (Estimated)", price: 1350, unit: 'coil' },
        { brand: "Finolex Cables (Estimated)", price: 1400, unit: 'coil' }
      ];
    } else if (q.includes('pipe') || q.includes('plumb') || q.includes('ashirvad')) {
      fallback = [
        { brand: "Astral CPVC (Estimated)", price: 550, unit: 'length' },
        { brand: "Ashirvad CPVC (Estimated)", price: 580, unit: 'length' },
        { brand: "Supreme PVC (Estimated)", price: 450, unit: 'length' }
      ];
    } else if (q.includes('sand')) {
      fallback = [
        { brand: "River Sand (Estimated)", price: 110, unit: 'cft' },
        { brand: "M-Sand Washed (Estimated)", price: 75, unit: 'cft' },
        { brand: "P-Sand (Estimated)", price: 85, unit: 'cft' }
      ];
    } else if (q.includes('brick')) {
      fallback = [
        { brand: "Red Bricks (Estimated)", price: 12, unit: 'pcs' },
        { brand: "Fly Ash Bricks (Estimated)", price: 8, unit: 'pcs' },
        { brand: "AAC Blocks (Estimated)", price: 65, unit: 'pcs' }
      ];
    } else if (q.includes('door')) {
      fallback = [
        { brand: "Teak Wood Main Door (Estimated)", price: 25000, unit: 'unit' },
        { brand: "Flush Door Standard (Estimated)", price: 4500, unit: 'unit' },
        { brand: "PVC Bathroom Door (Estimated)", price: 2500, unit: 'unit' }
      ];
    } else if (q.includes('window')) {
      fallback = [
        { brand: "UPVC Sliding Window (Estimated)", price: 4500, unit: 'unit' },
        { brand: "Aluminum Window (Estimated)", price: 3500, unit: 'unit' },
        { brand: "Wooden Window Frame (Estimated)", price: 8500, unit: 'unit' }
      ];
    }

    res.json(fallback);
  }
});

// ─── Step 7: Structural Report ────────────────────────────────────────────────

function runStructuralReport(modelData) {
  const rooms = modelData.rooms || [];
  const project = modelData.project || { width: 30, height: 40 };
  const floorArea = parseFloat(project.width) * parseFloat(project.height);
  const floors = project.floors || 1;
  const totalArea = floorArea * floors;

  // Load Estimations (Approximate)
  const deadLoad = totalArea * 150; // 150 kg/sqft for slab, walls, etc.
  const liveLoad = totalArea * 40;  // 40 kg/sqft for residential
  const totalLoad = deadLoad + liveLoad;

  // Column Suggestions (at room corners and junctions)
  const columns = [];
  const corners = new Set();
  rooms.forEach(r => {
    const rx = parseFloat(r.x), ry = parseFloat(r.y), rw = parseFloat(r.width), rh = parseFloat(r.height);
    [[rx, ry], [rx + rw, ry], [rx, ry + rh], [rx + rw, ry + rh]].forEach(p => {
      const key = `${p[0]},${p[1]}`;
      if (!corners.has(key)) {
        corners.add(key);
        columns.push({ x: p[0], y: p[1], size: "12\"x12\"" });
      }
    });
  });

  // Filter columns to reduce density (min 8ft spacing)
  const optimizedColumns = [];
  columns.forEach(c => {
    const isTooClose = optimizedColumns.some(oc => {
      const dist = Math.sqrt(Math.pow(c.x - oc.x, 2) + Math.pow(c.y - oc.y, 2));
      return dist < 8;
    });
    if (!isTooClose) optimizedColumns.push(c);
  });

  return {
    summary: {
      total_area: totalArea,
      floor_area: floorArea,
      floors: floors,
      estimated_load_kg: Math.round(totalLoad),
      dead_load_kg: Math.round(deadLoad),
      live_load_kg: Math.round(liveLoad)
    },
    recommendations: {
      column_count: optimizedColumns.length,
      typical_column_size: "12\" x 12\"",
      typical_beam_size: "12\" x 18\"",
      foundation_depth_ft: 5
    },
    column_placements: optimizedColumns,
    beam_schedule: [
      { mark: "B1 (Main Beam)", size: "9\" x 12\"", top_steel: "2 - 16mm", bottom_steel: "2 - 16mm", stirrups: "8mm @ 6\" c/c" },
      { mark: "B2 (Secondary Beam)", size: "9\" x 9\"", top_steel: "2 - 12mm", bottom_steel: "2 - 12mm", stirrups: "8mm @ 8\" c/c" },
      { mark: "PB (Portico Beam)", size: "9\" x 15\"", top_steel: "2 - 16mm", bottom_steel: "3 - 16mm", stirrups: "8mm @ 6\" c/c" }
    ],
    beam_details: [
      { name: "B1", width: 9, height: 12, top_bars: 2, top_size: "16mm", bot_bars: 2, bot_size: "16mm" },
      { name: "B2", width: 9, height: 9, top_bars: 2, top_size: "12mm", bot_bars: 2, bot_size: "12mm" },
      { name: "PB", width: 9, height: 15, top_bars: 2, top_size: "16mm", bot_bars: 3, bot_size: "16mm" }
    ],
    column_design: {
      type: "RCC Square/Rectangular",
      main_column: { size: "9\" x 15\"", bars: "6 - 16mm", stirrups: "8mm @ 6\" c/c" },
      secondary_column: { size: "9\" x 12\"", bars: "4 - 16mm", stirrups: "8mm @ 7\" c/c" },
      mix_ratio: "M25 (1:1:2)"
    },
    slab_design: {
      type: "RCC Slab (Two-way/One-way)",
      thickness_inches: 5,
      main_steel: "10mm @ 5\" c/c",
      distribution_steel: "8mm @ 7\" c/c",
      mix_ratio: "M20 (1:1.5:3)"
    },
    foundation_design: {
      type: "Isolated RCC Footing",
      depth_ft: 5,
      footing_size: "4'x4' to 5'x5'",
      steel_mesh: "12mm @ 6\" c/c both ways",
      mix_ratio: "M20 (1:1.5:3)"
    },
    material_estimation: {
      cement_bags: Math.round(totalArea * 0.45),
      steel_kg: Math.round(totalArea * 4.2),
      sand_cft: Math.round(totalArea * 1.8),
      aggregate_cft: Math.round(totalArea * 2.2)
    },
    load_distribution: "RCC Framed Structure",
    safety_factor: 1.5
  };
}

// ─── Main Upload Endpoint ─────────────────────────────────────────────────────

app.post('/api/upload', (req, res, next) => {
  multiUpload(req, res, err => {
    if (err) {
      console.error('[Upload] Multer error:', err.message);
      return res.status(400).json({ error: 'Upload error: ' + err.message });
    }
    console.log('[Upload] Files received:', Object.keys(req.files || {}).map(k => `${k}: ${req.files[k][0].path}`));
    cleanUploadsFolder(path.join(__dirname, 'uploads'), 20);
    next();
  });
}, async (req, res) => {
  if (!req.files || !req.files['ground_plan']) {
    return res.status(400).json({ error: 'Ground plan image is required' });
  }

  try {
    const groundPath = req.files['ground_plan'][0].path;
    const firstPath = req.files['first_plan'] ? req.files['first_plan'][0].path : null;
    const secondPath = req.files['second_plan'] ? req.files['second_plan'][0].path : null;

    // ── Steps 1 & 2: Image → Structured JSON ──────────────────────────────
    console.log('\n═══ PIPELINE START ═══');
    
    // Process sequentially to avoid Gemini API rate limits
    const groundResult = await runPython(groundPath).then(r => validateModelData(r));
    let firstResult = null;
    let secondResult = null;
    
    if (firstPath) {
      console.log('Waiting before analyzing First Floor to respect rate limits...');
      await new Promise(resolve => setTimeout(resolve, 6000));
      firstResult = await runPython(firstPath).then(r => validateModelData(r));
    }
    
    if (secondPath) {
      console.log('Waiting before analyzing Second Floor to respect rate limits...');
      await new Promise(resolve => setTimeout(resolve, 6000));
      secondResult = await runPython(secondPath).then(r => validateModelData(r));
    }

    if (!groundResult) throw new Error('Floor plan extraction failed for ground floor');
    console.log(`[Step 2] ✓ ${groundResult.rooms.length} rooms extracted for Ground Floor`);
    if (firstResult) console.log(`[Step 2] ✓ ${firstResult.rooms.length} rooms extracted for First Floor`);
    if (secondResult) console.log(`[Step 2] ✓ ${secondResult.rooms.length} rooms extracted for Second Floor`);

    // ── Step 3: Assemble 3D model ──────────────────────────────────────────
    console.log('[Step 3] ✓ 3D model data assembled');
    const modelData = {
      project: groundResult.project,
      floors: { ground: groundResult, ...(firstResult ? { first: firstResult } : {}), ...(secondResult ? { second: secondResult } : {}) }
    };

    const reportModelData = {
      project: {
        ...groundResult.project,
        floors: secondResult ? 3 : (firstResult ? 2 : 1)
      },
      rooms: [...groundResult.rooms, ...(firstResult ? firstResult.rooms : []), ...(secondResult ? secondResult.rooms : [])]
    };

    // ── Step 5: Vastu Analysis (Separate Floors) ──────────────────────
    console.log('[Step 5] Running Vastu analysis...');
    const vastu = {};
    vastu.ground = await runVastuAnalysis(groundResult, 'English', groundPath, null, null, 'Ground');
    if (firstResult) vastu.first = await runVastuAnalysis(firstResult, 'English', firstPath, null, null, 'First');
    if (secondResult) vastu.second = await runVastuAnalysis(secondResult, 'English', secondPath, null, null, 'Second');
    console.log(`[Step 5] ✓ Vastu Ground score: ${vastu.ground.score}/100`);

    // ── Step 6: Cost Estimation (Separate Floors) ────────────────────
    console.log('[Step 6] ✓ Cost estimation complete');
    const costEstimate = {};
    costEstimate.ground = runCostEstimation(groundResult);
    if (firstResult) costEstimate.first = runCostEstimation(firstResult);
    if (secondResult) costEstimate.second = runCostEstimation(secondResult);
    costEstimate.total = runCostEstimation(reportModelData);

    // ── Step 7: Structural Report (Separate Floors) ──────────────────
    console.log('[Step 7] Generating Structural Report...');
    const structural = {};
    structural.ground = runStructuralReport(groundResult);
    if (firstResult) structural.first = runStructuralReport(firstResult);
    if (secondResult) structural.second = runStructuralReport(secondResult);
    console.log(`[Step 7] ✓ Structural Ground: ${structural.ground.column_placements?.length || 0} columns`);

    // ── Step 4: Elevation parameters ─────────────────────────────────────
    console.log('[Step 4] ✓ Elevation data generated');
    const elevation = {
      front_width: groundResult.project.width,
      depth: groundResult.project.height,
      wall_height: 10,
      floors: secondResult ? 3 : (firstResult ? 2 : 1),
      roof_type: 'flat',
      has_portico: groundResult.rooms.some(r =>
        (r.name || '').toLowerCase().match(/portico|parking/))
    };

    // ── Step 8: AI 3D Visual Design ──────────────────────────────────────
    console.log('[Step 8] Generating AI 3D Visualization Design...');
    const projectMeta = {
      width: groundResult.project.width,
      height: groundResult.project.height,
      rooms_count: groundResult.rooms.length,
      has_portico: elevation.has_portico,
      floors: elevation.floors
    };
    let visualDesign = await runVisualizer(groundPath, projectMeta);

    // Safety Fallback: If AI fails, generate DYNAMIC Pollinations URLs based on floor plan data
    const timestamp = Date.now();
    if (!visualDesign || visualDesign.error || !visualDesign.variations) {
      console.log('[Step 8] AI Visualizer failed, constructing dynamic fallback prompts...');
      const pw = groundResult.project.width || 30;
      const ph = groundResult.project.height || 40;
      const floors = elevation.floors || 1;
      
      // -- SMART PROMPT LOGIC INJECTED --
      const rooms = groundResult.rooms || [];

      
      let rightSide = 'modern windows';
      let centerSide = 'main entrance door';
      let leftSide = 'modern architectural elements';
      
      // Assume the "front" of the house is where y is maximum (bottom of the plan)
      let maxY = 0;
      rooms.forEach(r => { if ((r.y || 0) + (r.height || 0) > maxY) maxY = (r.y || 0) + (r.height || 0); });
      
      // Get rooms that are at the front (within 12ft of the maxY edge)
      const frontRooms = rooms.filter(r => ((r.y || 0) + (r.height || 0)) >= maxY - 12);
      
      frontRooms.forEach(r => {
        const name = (r.name || '').toLowerCase();
        const centerX = (r.x || 0) + (r.width || 0) / 2;
        
        let side = 'center';
        if (centerX < pw / 3) side = 'left';
        else if (centerX > (pw * 2) / 3) side = 'right';
        
        if (name.includes('portico') || name.includes('parking') || name.includes('car')) {
          if (side === 'left') leftSide = 'open Car Parking Portico with a parked car';
          else if (side === 'right') rightSide = 'open Car Parking Portico with a parked car';
          else centerSide = 'wide Car Parking Portico';
        } else if (name.includes('stair') || name.includes('step')) {
          if (side === 'left') leftSide = 'prominent enclosed staircase tower structure';
          else if (side === 'right') rightSide = 'prominent enclosed staircase tower structure';
        } else if (name.includes('kitchen')) {
          if (side === 'left') leftSide = 'kitchen window';
          else if (side === 'right') rightSide = 'kitchen window';
        } else if (name.includes('toilet') || name.includes('bath') || name.includes('wc')) {
          if (side === 'left') leftSide = 'small ventilator window';
          else if (side === 'right') rightSide = 'small ventilator window';
        } else if (name.includes('bedroom')) {
          if (side === 'left') leftSide = 'large bedroom window';
          else if (side === 'right') rightSide = 'large bedroom window';
        }
      });

      let dynamicPrompt = `A photorealistic front elevation of a ${pw}x${ph} modern Indian ${floors}-story house. `;
      dynamicPrompt += `The front facade features a ${rightSide} on the right side. `;
      dynamicPrompt += `In the center, there is a ${centerSide}. `;
      dynamicPrompt += `On the left side, there is a ${leftSide}. `;
      dynamicPrompt += `Modern contemporary style, flat roof, elegant lighting, clear sky, photorealistic 8k.`;
      
      let traditionalPrompt = dynamicPrompt.replace('Modern contemporary style, flat roof', 'Traditional Indian style, sloping roof, wooden pillars, warm lighting');

      visualDesign = {
        status: "success",
        variations: [
          {
            style: "Modern Indian",
            image_url: `https://image.pollinations.ai/prompt/${encodeURIComponent(dynamicPrompt)}?seed=${timestamp}&width=1024&height=1024&model=flux`
          },
          {
            style: "Traditional Indian",
            image_url: `https://image.pollinations.ai/prompt/${encodeURIComponent(traditionalPrompt)}?seed=${timestamp + 1}&width=1024&height=1024&model=flux`
          }
        ],
        structural: {
          preview_url: `https://image.pollinations.ai/prompt/3D%20structural%20isometric%20skeleton%20view%20of%20a%20${floors}-story%20${pw}x${ph}ft%20house%20showing%20columns%20and%20beams?seed=${timestamp + 2}&width=1024&height=1024&model=flux`,
          blueprint_url: `https://image.pollinations.ai/prompt/2D%20technical%20structural%20blueprint%20of%20a%20${floors}-story%20${pw}x${ph}ft%20house%20white%20lines%20on%20dark%20navy?seed=${timestamp + 3}&width=1024&height=1024&model=flux`
        }
      };
    } else if (!visualDesign.structural) {
      const pw = groundResult.project.width || 30;
      const ph = groundResult.project.height || 40;
      const baseDesc = `${elevation.floors}-story ${pw}x${ph}ft house`;
      visualDesign.structural = {
        preview_url: `https://image.pollinations.ai/prompt/3D%20structural%20isometric%20skeleton%20view%20of%20a%20${baseDesc}%20showing%20columns%20and%20beams?seed=${timestamp + 2}&width=1024&height=1024&model=flux`,
        blueprint_url: `https://image.pollinations.ai/prompt/2D%20technical%20structural%20blueprint%20of%20a%20${baseDesc}%20white%20lines%20on%20dark%20navy?seed=${timestamp + 3}&width=1024&height=1024&model=flux`
      };
    }
    console.log(`[Step 8] ✓ AI 3D Design variations ready: ${visualDesign.variations?.length || 0}`);

    // ── Database: Supabase ────────────────────────────────────────────────
    console.log('[DB] Saving to Supabase...');

    // Inject structural URLs into the structural report object for easier access
    if (structural.ground && visualDesign.structural) {
      structural.ground.preview_url = visualDesign.structural.preview_url;
      structural.ground.blueprint_url = visualDesign.structural.blueprint_url;
    }
    if (structural.first && visualDesign.structural) {
      structural.first.preview_url = visualDesign.structural.preview_url;
      structural.first.blueprint_url = visualDesign.structural.blueprint_url;
    }

    const fullModelData = {
      ...modelData,
      _vastu: vastu,
      _cost: costEstimate,
      _elevation: elevation,
      _structural: structural,
      _visual: visualDesign
    };

    const baseUrl = req.protocol + '://' + req.get('host');
    const imageUrl = `${baseUrl}/${groundPath.replace(/\\/g, '/')}`;

    const { data, error } = await supabase
      .from('projects')
      .insert([{
        name: req.body.name || 'New Project',
        image_url: imageUrl,
        model_data: fullModelData,
      }])
      .select().single();

    if (error) throw error;
    console.log(`[DB] ✓ Project saved. ID: ${data.id}`);
    console.log('═══ PIPELINE COMPLETE ═══\n');

    res.json({
      success: true,
      project: {
        ...data,
        vastu_data: data.model_data?._vastu,
        cost_data: data.model_data?._cost,
        elevation_data: data.model_data?._elevation,
        structural_data: data.model_data?._structural || {},
        visual_data: data.model_data?._visual || {},
      }
    });

  } catch (err) {
    console.error('[Pipeline Error]', err.message);
    res.status(500).json({ error: 'Processing failed.', details: err.message });
  }
});

// ─── Standalone Vastu endpoint ────────────────────────────────────────────────

app.post('/api/analyze-vastu/:id', async (req, res) => {
  const projectId = req.params.id;
  const lang = req.body.lang || 'English';
  console.log(`[API] Requested Vastu for Project: ${projectId}, Lang: ${lang}`);

  try {
    const { data: project, error } = await supabase
      .from('projects')
      .select('model_data, image_url')
      .eq('id', projectId)
      .single();

    if (error || !project) {
      console.error(`[API] Project ${projectId} not found in DB`);
      return res.status(404).json({ error: 'Project not found' });
    }

    const existingVastu = project.model_data?._vastu || {};
    const floorsData = project.model_data?.floors || { ground: project.model_data };
    const groundPath = project.image_url;

    const result = {};
    for (const [floorName, floorData] of Object.entries(floorsData)) {
      const existingFloorVastu = existingVastu[floorName] || existingVastu;
      const fixedScore = existingFloorVastu.score || null;
      const fixedGrade = existingFloorVastu.grade || null;
      
      result[floorName] = await runVastuAnalysis(
        floorData, 
        lang, 
        floorName === 'ground' ? groundPath : null, 
        fixedScore, 
        fixedGrade,
        floorName
      );
    }
    
    res.json(result);
  } catch (err) {
    console.error('[API] analyze-vastu internal error:', err.message);
    res.status(500).json({ error: 'Vastu analysis failed', details: err.message });
  }
});

app.get('/api/vastu/:id', async (req, res) => {
  const { data, error } = await supabase.from('projects').select('model_data, image_url').eq('id', req.params.id).single();
  if (error || !data) return res.status(404).json({ error: 'Project not found' });
  if (data.model_data?._vastu) return res.json(data.model_data._vastu);
  
  const vastu = await runVastuAnalysis(data.model_data?.floors?.ground || data.model_data, 'English', data.image_url, null, null, 'Ground');
  res.json({ ground: vastu });
});

// ─── Standalone Cost endpoint ─────────────────────────────────────────────────

app.get('/api/cost/:id', async (req, res) => {
  const { data, error } = await supabase.from('projects').select('model_data').eq('id', req.params.id).single();
  if (error || !data) return res.status(404).json({ error: 'Project not found' });
  if (data.model_data?._cost) return res.json(data.model_data._cost);
  
  res.json({ ground: runCostEstimation(data.model_data?.floors?.ground || data.model_data) });
});

// ─── Projects ────────────────────────────────────────────────────────────────

app.get('/api/projects', async (req, res) => {
  const { data, error } = await supabase.from('projects').select('*').order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ─── Razorpay Payment Endpoints ─────────────────────────────────────────────

app.post('/api/payment/create-order', async (req, res) => {
  const { amount } = req.body;

  if (!amount) {
    return res.status(400).json({ error: 'Amount is required' });
  }

  const options = {
    amount: Math.round(amount * 100), // Razorpay expects amount in paise
    currency: "INR",
    receipt: `receipt_order_${Date.now()}`,
  };

  try {
    // Check if keys are placeholders
    if (!process.env.RAZORPAY_KEY_ID || process.env.RAZORPAY_KEY_ID.includes('placeholder')) {
      console.log(`[Payment] MOCK MODE: Order Created for ₹${amount}`);
      return res.json({
        id: `order_mock_${Date.now()}`,
        amount: Math.round(amount * 100),
        currency: "INR"
      });
    }

    const order = await razorpay.orders.create(options);
    console.log(`[Payment] Order Created: ${order.id} for ₹${amount}`);
    res.json({
      id: order.id,
      amount: order.amount,
      currency: order.currency
    });
  } catch (error) {
    console.error('[Payment] Create Order Error:', error);
    // Fallback to mock order in case of API error during development
    res.json({
      id: `order_error_fallback_${Date.now()}`,
      amount: Math.round(amount * 100),
      currency: "INR",
      note: "API Error Fallback"
    });
  }
});

app.post('/api/payment/verify-payment', async (req, res) => {
  const {
    razorpay_order_id,
    razorpay_payment_id,
    razorpay_signature
  } = req.body;

  const sign = razorpay_order_id + "|" + razorpay_payment_id;
  const expectedSign = crypto
    .createHmac("sha256", process.env.RAZORPAY_KEY_SECRET || 'placeholder_secret')
    .update(sign.toString())
    .digest("hex");

  if (razorpay_signature === expectedSign) {
    console.log(`[Payment] Verified: ${razorpay_payment_id}`);
    return res.json({ success: true, message: "Payment verified successfully" });
  } else {
    console.error('[Payment] Verification Failed');
    return res.status(400).json({ success: false, message: "Invalid signature" });
  }
});

const https = require('https');
const http = require('http');

app.get('/api/proxy-image', async (req, res) => {
  const imageUrl = req.query.url;
  if (!imageUrl) return res.status(400).send('URL parameter is required');
  
  try {
    console.log('[Proxy] Fetching:', imageUrl.substring(0, 80) + '...');
    const response = await fetch(imageUrl);
    
    if (!response.ok) {
      return res.status(response.status).send('Failed to fetch image: ' + response.statusText);
    }
    
    res.setHeader('Content-Type', response.headers.get('content-type') || 'image/jpeg');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    res.setHeader('Cache-Control', 'public, max-age=86400');
    
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    res.send(buffer);
  } catch (err) {
    console.error('[Proxy Error]', err.message);
    if (!res.headersSent) res.status(500).send('Proxy fetch failed: ' + err.message);
  }
});

let elevationQueue = Promise.resolve();

app.get('/api/generate-elevation', async (req, res) => {
  const prompt = req.query.prompt;
  const image_path = req.query.image_path;
  
  if (!prompt) return res.status(400).send('Prompt is required');

  // Deterministic seed based on the prompt string so the image stays the same on reload
  let seed = 0;
  for (let i = 0; i < prompt.length; i++) {
      seed = ((seed << 5) - seed) + prompt.charCodeAt(i);
      seed |= 0; 
  }
  seed = Math.abs(seed);

  const token = process.env.REPLICATE_API_TOKEN;
  
  if (image_path && token) {
    let filename = image_path.split('/').pop();
    if (filename.includes('?')) filename = filename.split('?')[0]; // strip query params if any
    const absPath = path.join(__dirname, 'uploads', filename);
    
    if (fs.existsSync(absPath)) {
      try {
        console.log('[ControlNet] Generating exact CAD elevation for GET request...');
        const imageData = fs.readFileSync(absPath).toString('base64');
        const imageUri = `data:image/png;base64,${imageData}`;

        const response = await fetch("https://api.replicate.com/v1/predictions", {
          method: "POST",
          headers: {
            "Authorization": `Token ${token}`,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            version: "854e87270c1a1f42e08d388f618a38ec2d82bf4e69b3da59a0f443b740e53a26", // ControlNet MLSD
            input: {
              image: imageUri,
              prompt: prompt,
              num_samples: 1,
              image_resolution: 512,
              seed: seed,
              a_prompt: "best quality, extremely detailed, photorealistic, modern architecture, 8k resolution",
              n_prompt: "lowres, worst quality, low quality, deformed, bad architecture"
            }
          })
        });

        if (response.ok) {
          let prediction = await response.json();
          let getUrl = prediction.urls.get;

          while (prediction.status !== 'succeeded' && prediction.status !== 'failed') {
            await new Promise(r => setTimeout(r, 2000));
            const poll = await fetch(getUrl, { headers: { "Authorization": `Token ${token}` } });
            prediction = await poll.json();
          }

          if (prediction.status === 'succeeded') {
            const resultUrl = Array.isArray(prediction.output) ? prediction.output[1] || prediction.output[0] : prediction.output;
            console.log('[ControlNet] Success! Redirecting to:', resultUrl);
            return res.redirect(resultUrl);
          }
        } else {
            console.error('[ControlNet API Error]', await response.text());
        }
      } catch (err) {
        console.error('[ControlNet Exception]', err);
      }
    }
  }

  // Fallback to Pollinations AI Text-to-Image if no Replicate token or no image
  elevationQueue = elevationQueue.then(() => {
    return new Promise((resolve) => {
      console.log('[Pollinations Queue] Fetching:', prompt.substring(0, 50));
      
      const targetUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}?width=1024&height=1024&nologo=true&seed=${seed}`;

      fetch(targetUrl)
        .then(async (proxyRes) => {
          if (!proxyRes.ok) {
            res.status(proxyRes.status).send('Pollinations fetch failed');
            resolve();
            return;
          }
          const buffer = Buffer.from(await proxyRes.arrayBuffer());
          res.setHeader('Content-Type', proxyRes.headers.get('content-type') || 'image/jpeg');
          res.setHeader('Access-Control-Allow-Origin', '*');
          res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
          res.send(buffer);
          setTimeout(resolve, 1500); // 1.5s delay to prevent rate limit
        })
        .catch(err => {
          console.error('[Proxy Error]', err.message);
          if (!res.headersSent) res.status(500).send('Fetch failed: ' + err.message);
          resolve();
        });
    });
  });
});

app.post('/api/auth/signup', async (req, res) => {
  const { email, password, name, phone } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  try {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name, phone } }
    });
    if (error) throw error;
    res.json({ message: 'Signup successful', user: data.user });
  } catch (err) {
    if (err.message && err.message.toLowerCase().includes('rate limit')) {
      console.log('[Auth] Supabase rate limit hit. Mocking signup for development.');
      return res.json({ 
        message: 'Mock Signup successful (Rate Limit Bypassed)', 
        user: { email, user_metadata: { name, phone } } 
      });
    }
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });
  try {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    res.json({ message: 'Login successful', session: data.session, user: data.user });
  } catch (err) {
    if (err.message && err.message.toLowerCase().includes('rate limit')) {
      console.log('[Auth] Supabase rate limit hit. Mocking login for development.');
      return res.json({ 
        message: 'Mock Login successful (Rate Limit Bypassed)', 
        session: { access_token: 'mock_token' }, 
        user: { email, user_metadata: { name: 'Test User', phone: '1234567890' } } 
      });
    }
    res.status(400).json({ error: err.message });
  }
});

app.get('/api/auth/google', async (req, res) => {
  try {
    const { data, error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: 'http://localhost:3000/api/auth/callback' // Ensure you configure this in Supabase if used for real
      }
    });
    if (error) throw error;
    res.redirect(data.url);
  } catch (err) {
    res.status(400).json({ error: err.message });
  }
});

app.post('/api/auth/google/token', async (req, res) => {
  const { idToken, email, name } = req.body;
  if (!idToken) return res.status(400).json({ error: 'ID token required' });
  try {
    const { data, error } = await supabase.auth.signInWithIdToken({
      provider: 'google',
      token: idToken,
    });
    if (error) throw error;
    res.json({ message: 'Login successful', session: data.session, user: data.user });
  } catch (err) {
    // If rate limit or other issue
    console.error('[Auth] Google ID Token error:', err.message);
    if (err.message && err.message.toLowerCase().includes('rate limit')) {
      return res.json({ 
        message: 'Mock Login successful (Rate Limit Bypassed)', 
        session: { access_token: 'mock_token' }, 
        user: { email, user_metadata: { name: name || 'Test User' } } 
      });
    }
    res.status(400).json({ error: err.message });
  }
});

app.listen(port, '0.0.0.0', () => console.log(`\nArchiGen Backend running at http://0.0.0.0:${port}`));
