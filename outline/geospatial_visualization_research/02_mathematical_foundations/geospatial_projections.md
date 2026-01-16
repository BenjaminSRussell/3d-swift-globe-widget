# Geospatial Projections and Coordinate Systems

## Introduction

Geospatial projections are mathematical transformations that convert the curved surface of the Earth into a flat, two-dimensional representation. For the Cyber-Physical Globe project, understanding these projections is crucial for implementing accurate and visually appealing transitions between 3D and 2D views.

## Fundamental Concepts

### Geographic Coordinate System

**Latitude (φ)**: Measures north-south position
- Range: -90° to +90° (or -π/2 to +π/2 radians)
- Equator: 0°
- North Pole: +90°
- South Pole: -90°

**Longitude (λ)**: Measures east-west position
- Range: -180° to +180° (or -π to +π radians)
- Prime Meridian: 0° (Greenwich, England)
- International Date Line: ±180°

### Earth Models

#### Spherical Earth Model
```javascript
const EARTH_SPHERE = {
  radius: 6371.0, // kilometers
  circumference: 40075.0, // kilometers
  surfaceArea: 510072000 // square kilometers
};
```

#### WGS84 Ellipsoid Model (More Accurate)
```javascript
const WGS84 = {
  semiMajorAxis: 6378137.0, // meters (equatorial radius)
  semiMinorAxis: 6356752.314245, // meters (polar radius)
  flattening: 1 / 298.257223563,
  eccentricity: 0.0818191908426215
};

// Convert geodetic to Cartesian coordinates
function geodeticToCartesian(lat, lon, h = 0) {
  const phi = lat * Math.PI / 180;
  const lambda = lon * Math.PI / 180;
  
  const a = WGS84.semiMajorAxis;
  const e = WGS84.eccentricity;
  
  const N = a / Math.sqrt(1 - e * e * Math.sin(phi) * Math.sin(phi));
  
  const X = (N + h) * Math.cos(phi) * Math.cos(lambda);
  const Y = (N + h) * Math.cos(phi) * Math.sin(lambda);
  const Z = (N * (1 - e * e) + h) * Math.sin(phi);
  
  return { X, Y, Z };
}
```

## Map Projections

### Cylindrical Projections

#### Equirectangular (Plate Carrée)
**Forward Transformation**:
```
x = R × λ
y = R × φ
```

**Inverse Transformation**:
```
λ = x / R
φ = y / R
```

**Properties**:
- Simplest projection mathematically
- Equal area along meridians
- Severe area distortion at high latitudes
- Used for thematic world maps

#### Mercator Projection
**Forward Transformation**:
```
x = R × λ
y = R × ln(tan(π/4 + φ/2))
```

**Inverse Transformation**:
```
λ = x / R
φ = 2 × arctan(e^(y/R)) - π/2
```

**JavaScript Implementation**:
```javascript
function mercatorForward(lat, lon, radius = 6371) {
  const phi = lat * Math.PI / 180;
  const lambda = lon * Math.PI / 180;
  
  const x = radius * lambda;
  const y = radius * Math.log(Math.tan(Math.PI / 4 + phi / 2));
  
  return { x, y };
}

function mercatorInverse(x, y, radius = 6371) {
  const lambda = x / radius;
  const phi = 2 * Math.atan(Math.exp(y / radius)) - Math.PI / 2;
  
  return {
    lat: phi * 180 / Math.PI,
    lon: lambda * 180 / Math.PI
  };
}
```

**Properties**:
- Conformal (preserves angles)
- Rhumb lines are straight
- Cannot represent poles (φ = ±90°)
- Used for navigation charts

### Azimuthal Projections

#### Orthographic Projection
**Forward Transformation**:
```
x = R × cos(φ) × sin(λ - λ₀)
y = R × (cos(φ₀) × sin(φ) - sin(φ₀) × cos(φ) × cos(λ - λ₀))
```

**Properties**:
- Perspective projection from infinity
- Hemisphere can be shown
- Used for planetary views

#### Stereographic Projection
**Forward Transformation**:
```
k = 2R / (1 + sin(φ₀) × sin(φ) + cos(φ₀) × cos(φ) × cos(λ - λ₀))
x = k × cos(φ) × sin(λ - λ₀)
y = k × (cos(φ₀) × sin(φ) - sin(φ₀) × cos(φ) × cos(λ - λ₀))
```

**Properties**:
- Conformal
- All circles map to circles
- Used for polar regions

### Conic Projections

#### Albers Equal-Area Conic
**Forward Transformation**:
```
n = (sin(φ₁) + sin(φ₂)) / 2
C = cos²(φ₁) + 2n × sin(φ₁)
ρ = √(C - 2n × sin(φ)) / n
θ = n × (λ - λ₀)

x = ρ × sin(θ)
y = ρ₀ - ρ × cos(θ)
```

**Properties**:
- Equal-area projection
- Best for mid-latitude regions
- Used for US national maps

## Distance and Bearing Calculations

### Great Circle Distance

#### Haversine Formula
```javascript
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  
  return R * c; // Distance in km
}
```

#### Vincenty Formula (More Accurate)
```javascript
function vincentyDistance(lat1, lon1, lat2, lon2) {
  const a = 6378137; // WGS-84 semi-major axis
  const b = 6356752.314245; // WGS-84 semi-minor axis
  const f = 1 / 298.257223563; // WGS-84 flattening
  
  const L = (lon2 - lon1) * Math.PI / 180;
  const U1 = Math.atan((1 - f) * Math.tan(lat1 * Math.PI / 180));
  const U2 = Math.atan((1 - f) * Math.tan(lat2 * Math.PI / 180));
  
  const sinU1 = Math.sin(U1), cosU1 = Math.cos(U1);
  const sinU2 = Math.sin(U2), cosU2 = Math.cos(U2);
  
  let lambda = L, lambdaP, iterLimit = 100;
  
  do {
    const sinLambda = Math.sin(lambda), cosLambda = Math.cos(lambda);
    const sinSigma = Math.sqrt((cosU2 * sinLambda) * (cosU2 * sinLambda) +
                               (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda) *
                               (cosU1 * sinU2 - sinU1 * cosU2 * cosLambda));
    
    if (sinSigma === 0) return 0; // co-incident points
    
    const cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
    const sigma = Math.atan2(sinSigma, cosSigma);
    
    const sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
    const cosSqAlpha = 1 - sinAlpha * sinAlpha;
    
    const cos2SigmaM = cosSigma - 2 * sinU1 * sinU2 / cosSqAlpha;
    const C = f / 16 * cosSqAlpha * (4 + f * (4 - 3 * cosSqAlpha));
    
    lambdaP = lambda;
    lambda = L + (1 - C) * f * sinAlpha *
             (sigma + C * sinSigma * (cos2SigmaM + C * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
    
  } while (Math.abs(lambda - lambdaP) > 1e-12 && --iterLimit > 0);
  
  if (iterLimit === 0) return NaN; // formula failed to converge
  
  const uSq = cosSqAlpha * (a * a - b * b) / (b * b);
  const A = 1 + uSq / 16384 * (4096 + uSq * (-768 + uSq * (320 - 175 * uSq)));
  const B = uSq / 1024 * (256 + uSq * (-128 + uSq * (74 - 47 * uSq)));
  
  const deltaSigma = B * sinSigma * (cos2SigmaM + B / 4 * (cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM) -
                                     B / 6 * cos2SigmaM * (-3 + 4 * sinSigma * sinSigma) * (-3 + 4 * cos2SigmaM * cos2SigmaM)));
  
  const s = b * A * (sigma - deltaSigma); // distance in meters
  
  return s / 1000; // distance in kilometers
}
```

### Initial and Final Bearings

```javascript
function calculateBearing(lat1, lon1, lat2, lon2) {
  const lat1Rad = lat1 * Math.PI / 180;
  const lat2Rad = lat2 * Math.PI / 180;
  const deltaLon = (lon2 - lon1) * Math.PI / 180;
  
  const y = Math.sin(deltaLon) * Math.cos(lat2Rad);
  const x = Math.cos(lat1Rad) * Math.sin(lat2Rad) -
            Math.sin(lat1Rad) * Math.cos(lat2Rad) * Math.cos(deltaLon);
  
  const bearing = Math.atan2(y, x) * 180 / Math.PI;
  
  return (bearing + 360) % 360; // Normalize to 0-360°
}
```

## Great Circle Calculations

### Great Circle Path Generation

```javascript
function generateGreatCirclePath(lat1, lon1, lat2, lon2, numPoints = 100) {
  const path = [];
  
  // Convert to radians
  const lat1Rad = lat1 * Math.PI / 180;
  const lon1Rad = lon1 * Math.PI / 180;
  const lat2Rad = lat2 * Math.PI / 180;
  const lon2Rad = lon2 * Math.PI / 180;
  
  // Calculate the great circle distance
  const d = 2 * Math.asin(Math.sqrt(
    Math.pow(Math.sin((lat2Rad - lat1Rad) / 2), 2) +
    Math.cos(lat1Rad) * Math.cos(lat2Rad) * 
    Math.pow(Math.sin((lon2Rad - lon1Rad) / 2), 2)
  ));
  
  for (let i = 0; i <= numPoints; i++) {
    const f = i / numPoints;
    
    const A = Math.sin((1 - f) * d) / Math.sin(d);
    const B = Math.sin(f * d) / Math.sin(d);
    
    const x = A * Math.cos(lat1Rad) * Math.cos(lon1Rad) +
              B * Math.cos(lat2Rad) * Math.cos(lon2Rad);
    const y = A * Math.cos(lat1Rad) * Math.sin(lon1Rad) +
              B * Math.cos(lat2Rad) * Math.sin(lon2Rad);
    const z = A * Math.sin(lat1Rad) + B * Math.sin(lat2Rad);
    
    const lat = Math.atan2(z, Math.sqrt(x * x + y * y)) * 180 / Math.PI;
    const lon = Math.atan2(y, x) * 180 / Math.PI;
    
    path.push({ lat, lon });
  }
  
  return path;
}
```

## Tile System Mathematics

### Web Mercator Tile System

#### Tile Coordinate Calculation
```javascript
function latLonToTile(lat, lon, zoom) {
  const latRad = lat * Math.PI / 180;
  const n = Math.pow(2, zoom);
  
  const xTile = Math.floor((lon + 180) / 360 * n);
  const yTile = Math.floor((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * n);
  
  return { x: xTile, y: yTile };
}

function tileToLatLon(x, y, zoom) {
  const n = Math.pow(2, zoom);
  const lon = x / n * 360 - 180;
  const latRad = Math.atan(Math.sinh(Math.PI * (1 - 2 * y / n)));
  const lat = latRad * 180 / Math.PI;
  
  return { lat, lon };
}
```

#### Tile Bounds Calculation
```javascript
function getTileBounds(x, y, zoom) {
  const north = tileToLatLon(x, y, zoom).lat;
  const south = tileToLatLon(x, y + 1, zoom).lat;
  const west = tileToLatLon(x, y, zoom).lon;
  const east = tileToLatLon(x + 1, y, zoom).lon;
  
  return { north, south, east, west };
}
```

## Projection Selection Criteria

### Use Case Recommendations

| Projection | Use Case | Advantages | Disadvantages |
|------------|----------|------------|---------------|
| Equirectangular | Thematic maps | Simple, equal-area meridians | High distortion at poles |
| Mercator | Navigation | Conformal, straight rhumb lines | Cannot show poles |
| Orthographic | Globe views | Natural appearance | Limited to hemisphere |
| Stereographic | Polar regions | Conformal, shows entire pole | Area distortion |
| Albers | Regional maps | Equal-area | Complex mathematics |

### Performance Considerations

```javascript
const PROJECTION_PERFORMANCE = {
  equirectangular: {
    forward: 'O(1)',
    inverse: 'O(1)',
    complexity: 'low'
  },
  mercator: {
    forward: 'O(1)',
    inverse: 'O(1)',
    complexity: 'medium'
  },
  orthographic: {
    forward: 'O(1)',
    inverse: 'O(1)',
    complexity: 'low'
  },
  stereographic: {
    forward: 'O(1)',
    inverse: 'O(1)',
    complexity: 'medium'
  },
  albers: {
    forward: 'O(1)',
    inverse: 'O(n)', // iterative solution required
    complexity: 'high'
  }
};
```

## Conclusion

Understanding geospatial projections is fundamental to creating accurate and visually appealing geospatial visualizations. The choice of projection depends on the specific requirements of the application, including the geographic area of interest, the type of data being visualized, and the desired aesthetic properties.

For the Cyber-Physical Globe project, the equirectangular projection provides the optimal balance of simplicity, performance, and visual continuity for the 3D-to-2D morphing transformation.