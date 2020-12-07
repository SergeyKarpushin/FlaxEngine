// Copyright (c) 2012-2020 Wojciech Figat. All rights reserved.

#ifndef __ATMOSPHERE_FOG__
#define __ATMOSPHERE_FOG__

// Provides functions for atmospheric scattering and aerial perspective.
//
// Explanations:
// Scale Height = the altitude (height above ground) at which the average
//                atmospheric density is found.
// Optical Depth = also called optical length, airmass, etc.
//
// References:
// [GPUGems2] GPU Gems 2: Accurate Atmospheric Scattering by Sean O'Neil.
// [GPUPro3]  An Approximation to the Chapman Grazing-Incidence Function for
//            Atmospheric Scattering, GPU Pro3, pp. 105.
// Papers bei Bruneton, Nishita, etc.
//
// This code contains embedded portions of free sample source code from 
// http://www-evasion.imag.fr/Membres/Eric.Bruneton/PrecomputedAtmosphericScattering2.zip, Author: Eric Bruneton, 
// 08/16/2011, Copyright (c) 2008 INRIA, All Rights Reserved, which have been altered from their original version.

#include "./Flax/Atmosphere.hlsl"

static const float HeightOffset = 0.01f;

/** inscattered light along ray x+tv, when sun in direction s (=S[L]-T(x,x0)S[L]|x0) */
float3 GetInscatterColor(float fogDepth, float3 X, float T, float3 V, float3 S, float radius, float Mu, out float3 attenuation, bool isSceneGeometry) 
{
    float3 result = float3(0.f, 0.f, 0.f); 	// X in space and ray looking in space, intialize
	attenuation = float3(1.f, 1.f, 1.f);

	float D = -radius * Mu - sqrt(radius * radius * (Mu * Mu - 1.0) + RadiusAtmosphere * RadiusAtmosphere);
    if (D > 0.0) 
	{ 
		// if X in space and ray intersects atmosphere
        // move X to nearest intersection of ray with top atmosphere boundary
        X += D * V;
        T -= D;
        Mu = (radius * Mu + D) / RadiusAtmosphere;
        radius = RadiusAtmosphere;
    }

	float Epsilon = 0.005f;//maybe 0.004?

	if (radius < RadiusGround + HeightOffset + Epsilon)
	{
		float Diff = (RadiusGround + HeightOffset + Epsilon) - radius;
		X -= Diff * V;
		T -= Diff;
		radius = RadiusGround + HeightOffset + Epsilon;
		Mu = dot(X, V) / radius;
	}

	if (radius <= RadiusAtmosphere && fogDepth > 0.f) 
	{ 
		float3 X0 = X + T * V;
		float R0 = length(X0);
		// if ray intersects atmosphere
		float Nu = dot(V, S);
		float MuS = dot(X, S) / radius;

		float MuHorizon = -sqrt(1.0 - (RadiusGround / radius) * (RadiusGround / radius));

		if (isSceneGeometry)
		{
			Mu = max(Mu, MuHorizon + Epsilon + 0.15);
		}
		else
		{ 
			Mu = max(Mu, MuHorizon + Epsilon);
		}

		float MuOriginal = Mu;
		float blendRatio = 0.0f;

		if (isSceneGeometry)
		{
			blendRatio = saturate(exp(-V.z) - 0.5);
			if (blendRatio < 1.0)
			{
				V.z = max(V.z, 0.15);
				V = normalize(V);
				float3 X1 = X + T * V;
				float R1 = length(X1);
				Mu = dot(X1, V) / R1; 
			}
		}

		float phaseR = PhaseFunctionR(Nu);
		float phaseM = PhaseFunctionM(Nu);
		float4 inscatter = max(Texture4DSample(AtmosphereInscatterTexture, radius, Mu, MuS, Nu), 0.0);

		if (T > 0.0) 
		{
#if ATMOSPHERIC_TEXTURE_SAMPLE_FIX
			// Avoids imprecision problems in transmittance computations based on textures
			attenuation = AnalyticTransmittance(radius, Mu, T);
#else
			attenuation = TransmittanceWithDistance(radius, Mu, V, X0);
#endif

			float Mu0 = dot(X0, V) / R0;
			float MuS0 = dot(X0, S) / R0;
			
			if (isSceneGeometry)
			{
				R0 = max(R0, radius);
			}
			
			if (R0 > RadiusGround + HeightOffset)
			{
				if (blendRatio < 1.0)
				{
					inscatter = max(inscatter - attenuation.rgbr * Texture4DSample(AtmosphereInscatterTexture, R0, Mu0, MuS0, Nu), 0.0);
#if ATMOSPHERIC_TEXTURE_SAMPLE_FIX
					// avoids imprecision problems near horizon by interpolating between two points above and below horizon
					if (!isSceneGeometry ) 
					{
						if (abs(Mu - MuHorizon) < Epsilon)
						{
							float Alpha = ((Mu - MuHorizon) + Epsilon) * 0.5f / Epsilon;

							Mu = MuHorizon - Epsilon;
							R0 = sqrt(radius * radius + T * T + 2.0 * radius * T * Mu);
							Mu0 = (radius * Mu + T) / R0;

							Mu0 = max(MuHorizon + Epsilon, Mu0);
							float4 Inscatter0 = Texture4DSample(AtmosphereInscatterTexture, radius, Mu, MuS, Nu);
							float4 Inscatter1 = Texture4DSample(AtmosphereInscatterTexture, R0, Mu0, MuS0, Nu);
							float4 InscatterA = max(Inscatter0 - attenuation.rgbr * Inscatter1, 0.0);

							Mu = MuHorizon + Epsilon;
							R0 = sqrt(radius * radius + T * T + 2.0 * radius * T * Mu);

							Mu0 = (radius * Mu + T) / R0;
							Mu0 = max(MuHorizon + Epsilon, Mu0);
							Inscatter0 = Texture4DSample(AtmosphereInscatterTexture, radius, Mu, MuS, Nu);
							Inscatter1 = Texture4DSample(AtmosphereInscatterTexture, R0, Mu0, MuS0, Nu);
							float4 InscatterB = max(Inscatter0 - attenuation.rgbr * Inscatter1, 0.0);

							inscatter = lerp(InscatterA, InscatterB, Alpha);
						}
					}
					else if (blendRatio > 0.0)
					{
						inscatter = lerp(inscatter, (1.0 - attenuation.rgbr) * max(Texture4DSample(AtmosphereInscatterTexture, radius, MuOriginal, MuS, Nu), 0.0),  blendRatio);
					}
#endif
				}
				else
				{
					inscatter = (1.0 - attenuation.rgbr) * inscatter; 
				}
			}
		}
#if ATMOSPHERIC_TEXTURE_SAMPLE_FIX
        // Avoids imprecision problems in Mie scattering when sun is below horizon
        inscatter.w *= smoothstep(0.00, 0.02, MuS);
#endif
        result = max(inscatter.rgb * phaseR + GetMie(inscatter) * phaseM, 0.0);
    } 
	
	return result;
}

// Ground radiance at end of ray x+tv, when sun in direction s attenuated bewteen ground and viewer (=R[L0]+R[L*])
float3 GetGroundColor(float4 sceneColor, float3 X, float T, float3 V, float3 S, float radius, float3 attenuation, bool isSceneGeometry)
{
    float3 result = float3(0.f, 0.f, 0.f); 	// ray looking at the sky (for intial value)
    if (T > 0.0) 
	{ 
		// if ray hits ground surface
        // ground Reflectance at end of ray, X0
        float3 X0 = X + T * V;
        float R0 = length(X0);
        float3 N = X0 / R0;
		N = X0 / R0;
		sceneColor.xyz = saturate(sceneColor.xyz + 0.05);

        float4 reflectance = sceneColor * float4(0.2, 0.2, 0.2, 1.0);

        // direct sun light (radiance) reaching X0
        float MuS = dot(N, S);
        float3 SunLight = isSceneGeometry ? float3(0.f, 0.f, 0.f) : TransmittanceWithShadow(R0, MuS);

        // precomputed sky light (irradiance) (=E[L*]) at X0
        float3 GroundSkyLight = Irradiance(AtmosphereIrradianceTexture, R0, MuS);

        // light reflected at X0 (=(R[L0]+R[L*])/T(X,X0))
		float3 groundColor = (reflectance.rgb * (max(MuS, 0.0) * SunLight + GroundSkyLight)) / PI;

        // water specular color due to SunLight
        if (!isSceneGeometry && reflectance.w > 0.0) 
		{
            float3 H = normalize(S - V);
            float fresnel = 0.02 + 0.98 * pow(1.0 - dot(-V, H), 5.0);
            float waterBrdf = fresnel * pow(max(dot(H, N), 0.0), 150.0);
            groundColor += reflectance.w * max(waterBrdf, 0.0) * SunLight;
        }

		result = attenuation * groundColor; //=R[L0]+R[L*]
    } 
    return result;
}

// Direct sun light for ray x+tv, when sun in direction s (=L0)
float3 GetSunColor(AtmosphericFogData atmosphericFog, float3 X, float T, float3 V, float3 S, float radius, float Mu) 
{
	if (T > 0.0)
	{
		return float3(0.0f, 0.0f, 0.0f);
	}
	else
	{
		float3 transmittance = radius <= RadiusAtmosphere ? TransmittanceWithShadow(radius, Mu) : float3(1.0, 1.0, 1.0); // T(X,xo)
		float sunIntensity = step(cos(PI * atmosphericFog.AtmosphericFogSunDiscScale / 180.0), dot(V, S)); // Lsun
		return transmittance * sunIntensity; // Eq (9)
	}
}

float3 inscatter(inout float3 x, inout float t, float3 v, float3 s, out float r, out float mu, out float3 attenuation)
{
    float3 result = 0;
    r = length(x);
    mu = dot(x, v) / r;
    float d = -r * mu - sqrt(r * r * (mu * mu - 1.0) + RadiusAtmosphere * RadiusAtmosphere);

	// if x in space and ray intersects atmosphere
    if (d > 0.0)
	{
        // move x to nearest intersection of ray with top atmosphere boundary
        x += d * v;
        t -= d;
        mu = (r * mu + d) / RadiusAtmosphere;
        r = RadiusAtmosphere;
    }

	// if ray intersects atmosphere
    if (r <= RadiusAtmosphere)
	{
        float nu = dot(v, s);
        float muS = dot(x, s) / r;
        float phaseR = PhaseFunctionR(nu);
        float phaseM = PhaseFunctionM(nu);
        float4 inscatter = max(Texture4DSample(AtmosphereInscatterTexture, r, mu, muS, nu), 0.0);

        if (t > 0.0)
		{
            float3 x0 = x + t * v;
            float r0 = length(x0);
            float rMu0 = dot(x0, v);
            float mu0 = rMu0 / r0;
            float muS0 = dot(x0, s) / r0;
#ifdef ATMOSPHERIC_TEXTURE_SAMPLE_FIX
            // avoids imprecision problems in transmittance computations based on textures
            attenuation = AnalyticTransmittance(r, mu, t);
#else
            attenuation = TransmittanceWithDistance(r, mu, v, x0);
#endif
            if (r0 > RadiusGround + 0.01)
			{
                // computes S[L]-T(x,x0)S[L]|x0
                inscatter = max(inscatter - attenuation.rgbr * Texture4DSample(AtmosphereInscatterTexture, r0, mu0, muS0, nu), 0.0);
#ifdef ATMOSPHERIC_TEXTURE_SAMPLE_FIX
                // avoids imprecision problems near horizon by interpolating between two points above and below horizon
                const float EPS = 0.004;
                float muHoriz = -sqrt(1.0 - (RadiusGround / r) * (RadiusGround / r));
                if (abs(mu - muHoriz) < EPS)
				{
                    float a = ((mu - muHoriz) + EPS) / (2.0 * EPS);

                    mu = muHoriz - EPS;
                    r0 = sqrt(r * r + t * t + 2.0 * r * t * mu);
                    mu0 = (r * mu + t) / r0;
                    float4 inScatter0 = Texture4DSample(AtmosphereInscatterTexture, r, mu, muS, nu);
                    float4 inScatter1 = Texture4DSample(AtmosphereInscatterTexture, r0, mu0, muS0, nu);
                    float4 inScatterA = max(inScatter0 - attenuation.rgbr * inScatter1, 0.0);

                    mu = muHoriz + EPS;
                    r0 = sqrt(r * r + t * t + 2.0 * r * t * mu);
                    mu0 = (r * mu + t) / r0;
                    inScatter0 = Texture4DSample(AtmosphereInscatterTexture, r, mu, muS, nu);
                    inScatter1 = Texture4DSample(AtmosphereInscatterTexture, r0, mu0, muS0, nu);
                    float4 inScatterB = max(inScatter0 - attenuation.rgbr * inScatter1, 0.0);

                    inscatter = lerp(inScatterA, inScatterB, a);
                }
#endif
            }
        }
#ifdef ATMOSPHERIC_TEXTURE_SAMPLE_FIX
        // avoids imprecision problems in Mie scattering when sun is below horizon
        inscatter.w *= smoothstep(0.00, 0.02, muS);
#endif
        result = max(inscatter.rgb * phaseR + GetMie(inscatter) * phaseM, 0.0);
    }

    return result;
}
/*
//ground radiance at end of ray x+tv, when sun in direction s
//attenuated bewteen ground and viewer (=R[L0]+R[L*])
float3 groundColor(float3 x, float t, float3 v, float3 s, float r, float mu, float3 attenuation)
{
    float3 result;
    if (t > 0.0)
	{
		// if ray hits ground surface
        // ground reflectance at end of ray, x0
        float3 x0 = x + t * v;
        float r0 = length(x0);
        float3 n = x0 / r0;

		float4 SceneColor = 0;
		
		SceneColor.xyz = saturate(SceneColor.xyz + 0.05);
		
		float4 Reflectance = SceneColor * float4(0.2, 0.2, 0.2, 1.0);
		
		if (r0 > RadiusGround + 0.01)
		{
			reflectance = float4(0.4, 0.4, 0.4, 0.0);
        }
		
        // direct sun light (radiance) reaching x0
        float muS = dot(n, s);
        float3 sunLight = transmittanceWithShadow(r0, muS);
		
        // precomputed sky light (irradiance) (=E[L*]) at x0
        float3 groundSkyLight = Irradiance(AtmosphereIrradianceTexture, r0, muS);
		
        // light reflected at x0 (=(R[L0]+R[L*])/T(x,x0))
        float3 groundColor = reflectance.rgb * (max(muS, 0.0) * sunLight + groundSkyLight) * ISun / M_PI;

        // water specular color due to sunLight
        if (reflectance.w > 0.0)
		{
            float3 h = normalize(s - v);
            float fresnel = 0.02 + 0.98 * pow(1.0 - dot(-v, h), 5.0);
            float waterBrdf = fresnel * pow(max(dot(h, n), 0.0), 150.0);
          groundColor += reflectance.w * max(waterBrdf, 0.0) * sunLight * ISun;
        }

        result = attenuation * groundColor; //=R[L0]+R[L*]
    } else { // ray looking at the sky
        result = 0.0;
    }
return result;
}
*/

static const float EPSILON_ATMOSPHERE = 0.002f;
static const float EPSILON_INSCATTER = 0.004f;

// input - viewPosition: view position in world space
// input - d: view ray in world space
// output - offset: distance to atmosphere or 0 if within atmosphere
// output - maxPathLength: distance traversed within atmosphere
// output - return value: intersection occurred true/false
bool intersectAtmosphere(in float3 viewPosition, in float3 d, out float offset, out float maxPathLength)
{  
	offset = 0.0f;
	maxPathLength = 0.0f;
	
	// vector from ray origin to center of the sphere
	float3 l = -viewPosition;
	float l2 = dot(l,l);
	float s = dot(l,d);
	
	// adjust top atmosphere boundary by small epsilon to prevent artifacts
	float r = Rt - EPSILON_ATMOSPHERE;
	float r2 = r*r;
	if(l2 <= r2)
	{
		// ray origin inside sphere, hit is ensured
		float m2 = l2 - (s * s);
		float q = sqrt(r2 - m2);
		maxPathLength = s + q;
		return true;
	}
	else if(s >= 0)
	{
		// ray starts outside in front of sphere, hit is possible
		float m2 = l2 - (s * s);
		if(m2 <= r2)
		{
			// ray hits atmosphere definitely
			float q = sqrt(r2 - m2);
			offset = s - q;
			maxPathLength = (s + q) - offset;
			return true;
		}
	}
	
	return false;
}

// input - surfacePos: reconstructed position of current pixel
// input - viewDir: view ray in world space
// input/output - attenuation: extinction factor along view path
// input/output - irradianceFactor: surface hit within atmosphere 1.0f, otherwise 0.0f
// output - return value: total in-scattered light
float3 GetInscatteredLight(AtmosphericFogData atmosphericFog, in float3 viewPosition, in float3 surfacePos, in float3 viewDir, in out float3 attenuation, in out float irradianceFactor)
{
	float3 inscatteredLight = float3(0.0f, 0.0f, 0.0f);
	float offset;
	float maxPathLength;

	if (intersectAtmosphere(viewPosition, viewDir, offset, maxPathLength))
	{
		return float3(offset / 10,0,0);

		float pathLength = distance(viewPosition, surfacePos);
		//return pathLength.xxx;

		// check if object occludes atmosphere
		if (pathLength > offset)
		{
			//return float3(1,0,0);
			
			// offsetting camera 
			float3 startPos = viewPosition + offset * viewDir;
			float startPosHeight = length(startPos);  pathLength -= offset;

			// starting position of path is now ensured to be inside atmosphere
			// was either originally there or has been moved to top boundary
			float muStartPos = dot(startPos, viewDir) / startPosHeight;
			float nuStartPos = dot(viewDir, atmosphericFog.AtmosphericFogSunDirection);
			float musStartPos = dot(startPos, atmosphericFog.AtmosphericFogSunDirection) / startPosHeight;

			// in-scattering for infinite ray (light in-scattered when
			// no surface hit or object behind atmosphere)
			float4 inscatter = max(Texture4DSample(AtmosphereInscatterTexture, startPosHeight, muStartPos, musStartPos, nuStartPos), 0.0f);
			float surfacePosHeight = length(surfacePos);
			float musEndPos = dot(surfacePos, atmosphericFog.AtmosphericFogSunDirection) / surfacePosHeight;
			//return float3(muStartPos, 0, 0);

			// check if object hit is inside atmosphere
			if (pathLength < maxPathLength)
			{
				//return float3(1,0,0);

				// reduce total in-scattered light when surface hit
				// within atmosphere
				// fíx described in chapter 5.1.1
				attenuation = AnalyticTransmittance(startPosHeight, muStartPos, pathLength); // TODO: optimize this!! here
				float muEndPos = dot(surfacePos, viewDir) / surfacePosHeight;
				float4 inscatterSurface = Texture4DSample(AtmosphereInscatterTexture, surfacePosHeight, muEndPos, musEndPos, nuStartPos);
				inscatter = max(inscatter - attenuation.rgbr * inscatterSurface, 0.0f);
				irradianceFactor = 1.0f;
			}
			else
			{
				//return float3(1,0,0);

				// retrieve extinction factor for inifinte ray
				// fíx described in chapter 5.1.1
				attenuation = AnalyticTransmittance(startPosHeight, muStartPos, pathLength); // TODO: optimize this! and here
			}
			/*
			// avoids imprecision problems near horizon by interpolating between
			// two points above and below horizon
			// fíx described in chapter 5.1.2
			float muHorizon = -sqrt(1.0 - (g_Rg / startPosHeight) * (g_Rg / startPosHeight));
			if (abs(muStartPos - muHorizon) < EPSILON_INSCATTER)
			{
				float mu = muHorizon - EPSILON_INSCATTER;
				float samplePosHeight = sqrt(startPosHeight*startPosHeight + pathLength * pathLength + 2.0f * startPosHeight * pathLength*mu);
				float muSamplePos = (startPosHeight * mu + pathLength) / samplePosHeight;
				float4 inScatter0 = Texture4DSample(AtmosphereInscatterTexture, startPosHeight, mu, musStartPos, nuStartPos);
				float4 inScatter1 = Texture4DSample(AtmosphereInscatterTexture, samplePosHeight, muSamplePos, musEndPos, nuStartPos);
				float4 inScatterA = max(inScatter0 - attenuation.rgbr * inScatter1, 0.0);
				mu = muHorizon + EPSILON_INSCATTER;
				samplePosHeight = sqrt(startPosHeight * startPosHeight + pathLength * pathLength + 2.0f * startPosHeight * pathLength * mu);
				muSamplePos = (startPosHeight * mu + pathLength) / samplePosHeight;
				inScatter0 = Texture4DSample(AtmosphereInscatterTexture, startPosHeight, mu, musStartPos, nuStartPos);
				inScatter1 = Texture4DSample(AtmosphereInscatterTexture, samplePosHeight, muSamplePos, musEndPos, nuStartPos);
				float4 inScatterB = max(inScatter0 - attenuation.rgbr * inScatter1, 0.0f);
				float t = ((muStartPos - muHorizon) + EPSILON_INSCATTER) / (2.0 * EPSILON_INSCATTER);
				inscatter = lerp(inScatterA, inScatterB, t);
			}
			*/

			// avoids imprecision problems in Mie scattering when sun is below
			//horizon
			// fíx described in chapter 5.1.3
			inscatter.w *= smoothstep(0.00, 0.02, musStartPos);
			float phaseR = PhaseFunctionR(nuStartPos);
			float phaseM = PhaseFunctionM(nuStartPos);
			inscatteredLight = max(inscatter.rgb * phaseR + GetMie(inscatter) * phaseM, 0.0f);

			float sunIntensity = 10;
			inscatteredLight *= sunIntensity;
		}
	}

	return inscatteredLight;
}

float4 GetAtmosphericFog(AtmosphericFogData atmosphericFog, float viewFar, float3 viewPosition, float3 viewVector, float sceneDepth, float3 sceneColor)
{
	float4 result = float4(1, 0, 0, 1);

#if 0
	
	float scale = 0.00001f * atmosphericFog.AtmosphericFogDistanceScale;// convert cm to km
	viewPosition.y = (viewPosition.y - atmosphericFog.AtmosphericFogGroundOffset) * atmosphericFog.AtmosphericFogAltitudeScale;
	//viewPosition *= atmosphericFog.AtmosphericFogDistanceScale;
	//viewPosition *= scale;
	
	//viewPosition *= scale;
	
	//if(length(worldPosition) > Rg)
	//	return float4(0, 0,0 ,0);
	
	float3 attenuation = float3(1.0f, 1.0f, 1.0f);
	float irradianceFactor = 0.0f;
	float3 inscatteredLight = GetInscatteredLight(atmosphericFog, viewPosition, worldPosition, viewVector, attenuation, irradianceFactor);
	//float3 inscatteredLight = GetInscatteredLight(atmosphericFog, worldPosition, viewPosition, viewVector, attenuation, irradianceFactor);
	
	return float4(inscatteredLight, 1);
	
	/*float offset = 0.0f;
	float maxPathLength = 0.0f;
	if(intersectAtmosphere(worldPosition, viewVector, offset, maxPathLength))
	{
		return float4(1,0,0,1);
	}*/
	
	return float4(0, 0, 0, 1);

#endif
	
#if 1

	// TODO: scale viewPosition from cm to km !!!!!!!
	
	float scale = 0.0001f * atmosphericFog.AtmosphericFogDistanceScale;
	viewPosition.y = (viewPosition.y - atmosphericFog.AtmosphericFogGroundOffset) * atmosphericFog.AtmosphericFogAltitudeScale;
	//viewPosition *= atmosphericFog.AtmosphericFogDistanceScale;
	viewPosition *= scale;
	//viewPosition.xz *= 0.00001f;
	
	//viewPosition *= scale;
	viewPosition.y += RadiusGround + HeightOffset;
	
	//viewPosition.y -= atmosphericFog.AtmosphericFogGroundOffset;
	//worldPosition
	float Radius = length(viewPosition);
	float3 V = normalize(viewVector);
	float Mu = dot(viewPosition, V) / Radius;
	float T = -Radius * Mu - sqrt(Radius * Radius * (Mu * Mu - 1.0) + RadiusGround * RadiusGround);
	
	//-Radius * Mu > sqrt(Radius * Radius * (Mu * Mu - 1.0) + RadiusGround * RadiusGround)
	/*
	float3 g = viewPosition - float3(0.0, 0.0, RadiusGround + 10.0);
	float a = V.x * V.x + V.y * V.y - V.z * V.z;
	float b = 2.0 * (g.x * V.x + g.y * V.y - g.z * V.z);
	float c = g.x * g.x + g.y * g.y - g.z * g.z;
	float d = -(b + sqrt(b * b - 4.0 * a * c)) / (2.0 * a);
	bool cone = d > 0.0 && abs(viewPosition.z + d * V.z - RadiusGround) <= 10.0;
	
	if (T > 0.0)
	{
		if (cone && d < T)
			T = d;
		//return float4(1,0,0,1);
	}
	else if (cone)
	{
		T = d;
		//return float4(0,0,1,1);
	}
	*/
	//return float4(V, 1);

	// TODO: create uniform param for that depth limit
	float depthThreshold = min(100.0f * atmosphericFog.AtmosphericFogDistanceScale, (viewFar * 0.997f) * scale); // 100km limit or far plane
	sceneDepth *= scale;

	float fogDepth = max(0.0f, sceneDepth - atmosphericFog.AtmosphericFogStartDistance);
	float shadowFactor = 1.0f;
	float DistanceRatio = min(fogDepth * 0.1f / atmosphericFog.AtmosphericFogStartDistance, 1.0f);
	bool isSceneGeometry = (sceneDepth < depthThreshold); // Assume as scene geometry
	//isSceneGeometry = false;
	if (isSceneGeometry)
	{
		shadowFactor = DistanceRatio * atmosphericFog.AtmosphericFogPower;
		T = max(sceneDepth + atmosphericFog.AtmosphericFogDistanceOffset, 1.0f);

		// TODO: fog for scene objects
		return 0;
		//return float4(0, 1, 0, 1);
	}

	float3 attenuation;
	float3 inscatterColor = GetInscatterColor(fogDepth, viewPosition, T, V, atmosphericFog.AtmosphericFogSunDirection, Radius, Mu, attenuation, isSceneGeometry); //S[L]-T(viewPosition,xs)S[l]|xs
	//float3 inscatterColor = inscatter(viewPosition, T, V, atmosphericFog.AtmosphericFogSunDirection, Radius, Mu, attenuation); //S[L]-T(viewPosition,xs)S[l]|xs
	//float3 groundColor = 0;
	float3 groundColor = GetGroundColor(float4(sceneColor.rgb, 1.f), viewPosition, T, V, atmosphericFog.AtmosphericFogSunDirection, Radius, attenuation, isSceneGeometry); //R[L0]+R[L*]
	float3 sun = GetSunColor(atmosphericFog, viewPosition, T, V, atmosphericFog.AtmosphericFogSunDirection, Radius, Mu); //L0

	float3 color = (atmosphericFog.AtmosphericFogSunPower) * (sun + groundColor + inscatterColor) * atmosphericFog.AtmosphericFogSunColor.rgb;
	//return float4(color, lerp(saturate(attenuation.r * atmosphericFog.AtmosphericFogDensityScale - atmosphericFog.AtmosphericFogDensityOffset), 1.0f, (1.0f - DistanceRatio)) );
	//return lerp(saturate(attenuation.r * atmosphericFog.AtmosphericFogDensityScale - atmosphericFog.AtmosphericFogDensityOffset), 1.0f, (1.0f - DistanceRatio));
	//color *= lerp(saturate(attenuation.r * atmosphericFog.AtmosphericFogDensityScale - atmosphericFog.AtmosphericFogDensityOffset), 1.0f, (1.0f - DistanceRatio));

	//return attenuation.bbbb;

	return float4(color, 1);

	//return float4(sun, 1);
	//return float4(inscatterColor + sun, 1);
	//return float4(sun + groundColor, 1);
	//return float4(sun + groundColor + inscatterColor, 1);

#endif

	return result;
}

float4 GetAtmosphericFog(AtmosphericFogData atmosphericFog, float viewFar, float3 worldPosition, float3 cameraPosition)
{
	float3 viewVector = worldPosition - cameraPosition;
	return GetAtmosphericFog(atmosphericFog, viewFar, cameraPosition, viewVector, length(viewVector), float3(0, 0, 0));
}

#endif
