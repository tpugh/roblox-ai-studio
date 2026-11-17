# HoopsMas "Claus #25" Roblox Avatar & Marketplace Asset Pack

## Included Files & Folder Structure
1. **2D_Classic_Clothing/**
   - `Claus25_Shirt_585x559.png` — Exact 585x559 official Roblox UV template featuring the red/gold/white #25 CLAUS basketball jersey, black belt with gold buckle, white fur waist hem, and white fur wrist cuffs.
   - `Claus25_Pants_585x559.png` — Exact 585x559 official Roblox UV template featuring red basketball shorts/pants with gold/white side stripes and custom gold/white/black high-top sneakers.
2. **3D_UGC_Accessories_OBJ/** (All watertight, single-mesh, under Roblox's 4,000-triangle UGC limit)
   - `SantaHat_Mesh.obj` — Slouching red Santa hat with white brim and pom-pom (`HatAttachment`).
   - `RoundShades_Mesh.obj` — Round black sunglasses (`FaceFrontAttachment`).
   - `SantaBeard_Mesh.obj` — Flowing white Santa beard and handlebar mustache (`FaceFrontAttachment`).
   - `Basketball_Prop.obj` — Regulation basketball prop (`RightGripAttachment` or `WaistBackAttachment`).
   - `GoldSneakerWing.obj` — Gold winged sneaker attachment (duplicate & mirror X = -1 for Left/Right `FootAttachment`).
3. **Textures_PBR/**
   - `SantaHat_Albedo.png` (512x512)
   - `GoldMetallic_Albedo.png` (512x512)
   - `Basketball_Albedo.png` (512x512)
4. **Roblox_Studio_Scripts/**
   - `LoadClaus25Avatar.lua` — Drop into `ServerScriptService` or run in the Roblox Studio Command Bar to spawn the R15 Blocky Rig, apply the exact skin tone (`RGB(108, 68, 45)`), and equip all assets.

## How to Load into Roblox Studio & Publish to Marketplace
1. **Classic Shirt & Pants:**
   - Open [Roblox Creator Hub](https://create.roblox.com/) -> **Avatar Items** -> **Classics** -> **Shirts** (and **Pants**).
   - Upload `Claus25_Shirt_585x559.png` and `Claus25_Pants_585x559.png` directly (no resizing needed).
2. **3D UGC Accessories:**
   - Open **Roblox Studio** -> **Avatar** tab -> **Accessory Fitting Tool (AFT)**.
   - Import each `.obj` file from `3D_UGC_Accessories_OBJ/`, assign its corresponding texture from `Textures_PBR/`, select the target attachment point (`HatAttachment`, `FaceFrontAttachment`, `RightGripAttachment`, `LeftFootAttachment`/`RightFootAttachment`), and click **Generate MeshPart Accessory**.
   - Right-click the generated Accessory in Explorer -> **Save to Roblox** to submit to the Roblox Marketplace!
