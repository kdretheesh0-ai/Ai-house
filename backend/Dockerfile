FROM nikolaik/python-nodejs:python3.10-nodejs20-slim

WORKDIR /app

# Install Python dependencies directly
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy package.json and install Node dependencies
COPY backend/package*.json ./
RUN npm install

# Copy the rest of the backend files
COPY backend/ .

# Expose the port the app runs on
EXPOSE 3000

# Command to run the application
CMD ["node", "server.js"]
