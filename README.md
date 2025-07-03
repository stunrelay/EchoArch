# 🎮 PocketArch 4.5

*Formerly known as EchoArch*

**Touch-friendly overlays + custom shaders for RetroArch**

Clean. Colorful. Complete.

PocketArch started as a stylish overlay pack for RetroArch on mobile — and in **v4.0**, it evolved into a full visual experience with **animated transparent overlays**, new platform support, and major shader design upgrades.  
**Now, version 4.5 brings integer scaling options to shaders.**


---

## ✅ Key Features

### 🎨 Overlays

- Transparent overlays with animated buttons that blend seamlessly with PocketArch shaders  
- All overlays support **both portrait and landscape modes with auto-rotation**  
- Updated support for **GB**, **Genesis**, **Saturn**, and **PSP** overlays (see all supported systems below)  
- Streamlined in-game pause menu across all overlays  
- Universal minimalist overlay that works with any RetroArch core  
- Non-transparent overlays are included for use without PocketArch shaders  
- Hidden QoL features:  
  - Hold to fast-forward at top-center (between the R/L buttons usually)  
  - DS overlay extras: screen layout toggle, mic input, lid-close action  

### ✨ Shaders

- New N64 and PSP shader support  
- Cartoon bezel styling for a consistent retro vibe  
- Optional retro screen effects (CRT, LCD, dot matrix)  
- Console-specific design elements  
- Console color-matched palettes for all supported systems  
- Compatible with **any overlay**, not just PocketArch  
- Scales beautifully across phones, tablets, TVs, PCs, and handhelds
- Adds integer scaling to the video output while preserving fullscreen bezel design (Note: Keep integer scaling off in the RetroArch settings as the shader handles all the scaling)

> ⚠️ Integer scaling shaders may increase bezel size and produce odd results depending on your device resolution  
> ⚠️ Fullscreen NDS shaders may break touchscreen support — best used only on non-touchscreen devices or when touchscreen input isn’t needed

---

## 🖼️ Supported Systems

- GB / GBC / GBA  
- NES / SNES  
- NDS / PSX / N64  
- Sega Genesis / Saturn  
- PSP (new!)  
- Universal overlays + shaders for any core  

---

## 📦 Setup Guide

### 🔽 Installing PocketArch

1. Go to the [PocketArch GitHub](https://github.com/PocketArch)  
2. Scroll to **Releases** → Download the latest **Source code (.zip)**  
3. Unzip the `PocketArch/` folder somewhere inside your **RetroArch** directory  

### 🎛 Loading Shaders & Overlays

> ⚠️ Since these are all **.slang shaders**, you must be using the **Vulkan video driver**. If not, the shader folders will appear empty.
>
> To set Vulkan:  
> - **Main Menu → Settings → Video → Output → Video Driver → Vulkan**  
> - Then go to **Main Menu → Configuration File → Save Current Configuration**

1. Launch a game → **Quick Menu → Shaders → Load Preset** → Choose a PocketArch shader  
2. **Save Preset → Save Core Preset**  
3. **Main Settings → Video → Scaling → Aspect Ratio → Full**  
4. Back in-game → **Quick Menu → On-Screen Overlay → Overlay Preset** → Choose a PocketArch overlay  
5. Set **Overlay Opacity → 1.00**  
6. Set **Auto-Scale Overlay → Off**  
7. **Quick Menu → Overrides → Save Core Override**

> ⚠️ For **N64 shaders**, go to **Quick Menu → Core Options** and set the video plugin to **ParaLLEl RDP** to enable  
> ✅ **Recommended:** Use **transparent overlays**  

---

## 🖼️ Screenshots (examples, not exhaustive)
> Note: Scaling may vary slightly depending on your screen size. Shaders shown in images are included in v4.0.

Shaders & Transparent Overlays:
![IMG_7650](https://github.com/user-attachments/assets/345a96a1-6706-4e1a-804b-10c33b6c4bc0)
![IMG_7648](https://github.com/user-attachments/assets/bcc791fa-7bbe-4c04-9427-480d1da23e5d)
![IMG_7645](https://github.com/user-attachments/assets/da6240e2-8e54-40fd-b3a7-99290c903d13)
![IMG_7641](https://github.com/user-attachments/assets/96564d07-0567-4d03-86c9-6f967e12f7fa)
![IMG_7638](https://github.com/user-attachments/assets/e5ffecfa-37a2-490f-a454-92371346612c)
![IMG_7637](https://github.com/user-attachments/assets/8eb0a27d-6482-4716-b12d-ea62520d4ea7)
![IMG_7635](https://github.com/user-attachments/assets/3a5bfedc-29e5-432b-aa12-4649b37a8d13)
![IMG_7633](https://github.com/user-attachments/assets/86f14bc1-860d-4636-b0b7-364c137273fe)
![IMG_7632](https://github.com/user-attachments/assets/389e1581-baef-4c9a-ba36-2f3da4a4bf95)
![IMG_7631](https://github.com/user-attachments/assets/f20bcd4c-ae50-459b-99b0-15f4db17bba2)
![IMG_7624](https://github.com/user-attachments/assets/59d1c945-8db3-4a65-89ec-88b9606bde70)
![IMG_7623](https://github.com/user-attachments/assets/9c6b4605-bbd8-4ef5-9317-05a151e0c5b3)
![IMG_7617](https://github.com/user-attachments/assets/46cef1f1-27b1-4d29-adab-b9f930b2f8e4)

![IMG_7615](https://github.com/user-attachments/assets/fb3cdd7c-185e-4598-b56b-036895e4bb77)

Landscape:
![IMG_7436](https://github.com/user-attachments/assets/44bee161-480a-4292-a66f-fa8567456bb8)
![IMG_7446](https://github.com/user-attachments/assets/e51c840e-d91d-4d52-9aca-b9bb12ed30c2)

Pause Menu:
![IMG_7653](https://github.com/user-attachments/assets/2101ee1e-577e-49c4-862e-e18f63a9e35d)
![IMG_7652](https://github.com/user-attachments/assets/d88821f4-b261-43da-98e8-61f0ccccca7d)


---

## 💬 Feedback Welcome

Love it? Running it on something weird? Share screenshots and let me know what device you're using!

---

## 🙏 Acknowledgements

Big thanks to the tools and creators that made this project possible:

- **[RetroPad Editor](https://valent-in.github.io/retropad-editor/)** — for making overlay editing intuitive and visual
- **[DeltArch](https://github.com/volkanturkut/DeltArch)** — for the original inspiration and framework
- **CRT-simple** shader by DariusG
- **LCD3x** shader by Themaister
- **Dot shader** by Guest.r and others in the libretro community
- The **libretro/RetroArch team** — for making incredible open-source emulation software

---

️☕ [Buy me a coffee](https://coff.ee/stunrelay)

