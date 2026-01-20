# URP-Pixel-Outline-Shader


!\[Preview](Image/1.png) (Image/2.png) (Image/3.png)

A full-screen post-processing effect for Unity Universal Render Pipeline (URP) that transforms 3D scenes into high-quality pixel art. This package includes a Scriptable Renderer Feature, a custom Shader, and a complete runtime UI controller.



🌟 Features

Dynamic Pixelation: Adjustable pixel size with sub-pixel stabilization to reduce jitter.

Dual Outline System:

Outer Outline: Depth-based detection for silhouette edges. Supports auto-darkening or custom colors.

Inner Outline: Normal-based detection for internal geometry details.

Color Grading: Color count quantization, saturation, contrast, and brightness controls.

Dithering: Adjustable Bayer matrix dithering for retro aesthetics.

Runtime UI: Includes a drag-and-drop UI script (using the New Input System) to tweak settings in-game.

Presets: Built-in presets for Retro, Modern, and Minimal styles.

📦 Dependencies

Unity 2021.3+

Universal Render Pipeline (URP)

Unity Input System (New)

🚀 Setup

Add the scripts and shader to your project.

Go to your active URP Renderer Data asset.

Click "Add Renderer Feature" and select Pixel Outline Feature.

Assign the material (created from the shader) to the feature.

