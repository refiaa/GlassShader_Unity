# Realistic Volumetric Glass Shader (Unity BRP)


<div align="center">
  <img src="./Media/image2.png" width="100%" alt="Refraction Detail" />
  <br/>
  <em>Real-time Volumetric Absorption & Refraction Demo</em>
</div>

[![GitHub release](https://img.shields.io/github/release/refiaa/GlassShader_Unity.svg?color=Green)](https://github.com/refiaa/GlassShader_Unity/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/refiaa/GlassShader_Unity/total?color=6451f1)](https://github.com/refiaa/GlassShader_Unity/releases/latest)

## Introduction

A physically-based glass shader designed for the **Unity Built-in Render Pipeline (BRP)** and **VRChat** environments.

This shader applies the **Beer-Lambert Law** to simulate physical light absorption based on the thickness of the glass. This achieves a realistic glass material where thin areas appear transparent, while thicker areas appear denser and darker.

The shader has been verified to work in **Unity 2022.3.22f1, 2022.3.22f2** and **VRChat**.

## Key Features

- Instead of simple texture compositing, it calculates the **distance (thickness)** light travels through the glass to reproduce exponential color absorption based on depth.
- It calculates the refractive index differences based on light wavelength to express prism-like edge details (Chromatic Aberration).

## Gallery

<div align="center">
  <table>
    <tr>
      <td align="center">
        <video src="https://github.com/user-attachments/assets/d4fabdca-d540-4030-88b0-dbd326be6298" width="100%" controls autoplay loop muted></video>
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src="./Media/image1.png" width="100%" alt="Thickness Visualization" />
      </td>
    </tr>
  </table>
</div>

## Compatibility

This shader has been tested and verified in the following environments:

* **Unity Version:**
  * 2022.3.22f1 (Verified)
  * 2022.3.22f2 (Verified)

* **Platform:**
  * VRChat
