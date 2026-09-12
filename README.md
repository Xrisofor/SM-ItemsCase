# Items Case / EN

![Mod Preview](https://github.com/Xrisofor/SM-ItemsCase/blob/main/preview.jpg?raw=true)

**Items Case** adds interactive cases with a full item roulette in the style of classic loot cases.

# How to get it in Survival mode?
To use Items Case, find it in one of the following places:

- [Modded Craftbot Recipes](https://steamcommunity.com/sharedfiles/filedetails/?id=2816900681) - the cases can be bought from the Mininghub Trader.
- [Fant Mod 3 Custom Gamemode](https://steamcommunity.com/sharedfiles/filedetails/?id=3772903275) - the cases can be bought from the Mininghub Trader.
- [FreeBuild Survival](https://steamcommunity.com/sharedfiles/filedetails/?id=3774231932) - the cases can be bought from the Mininghub Trader.

Can't find it? Make sure one of the custom games listed above is installed, and that Items Case is enabled in the mod list together with [Mod Database](https://steamcommunity.com/workshop/filedetails/?id=2504530003).

# How it works

Inside the case is a reel of random items. Interact with the case to open the roulette window, then press the unlock button. The reel will spin and stop on one item - that item goes straight into your inventory (or drops on the ground if your inventory is full). Once opened, the case is destroyed - it's single-use.

Which item you get is decided by the **server** before the animation even starts: the client only plays a nice spin animation toward the result the server already determined, so the outcome can't be influenced from the client side.

## How rarity is calculated

Item rarity isn't set manually (with a few exceptions, see below) - it's calculated:

- If the item has a crafting recipe (Craftbot, Portable Craftbot, Mechanic Station, Refinery, Farmer Hideout, and others), its value is recursively broken down through its ingredients all the way to raw materials.
- If it has no recipe, its value is calculated from physical properties: shape volume and material (metal, electronics, glass, wood, plastic, rubber, etc. - each material has its own value multiplier).
- Blocks get their rarity from their in-game durability rating: the tougher the block, the rarer it is.
- Tools always fall into the "Epic" category.
- All other items are sorted by their calculated value and split into groups by percentile: the cheapest 45% - Common, the next 27% - Uncommon, 18% - Rare, 7.8% - Epic, 2% - Legendary, and the most expensive 0.2% - Mythic.
- For certain unique items (jewelry, special resources, some decorative/quest items), rarity is fixed manually and doesn't go through the general calculation.

## Drop chance

Each rarity's chance is its weight (45 / 27 / 18 / 7.8 / 2 / 0.2), normalized among only the rarities allowed in that particular case. That's why different case types have different percentages:

| Rarity | Scrap Items Case | Items Case | Special Items Case |
| :--- | :---: | :---: | :---: |
| ⚪ Common | 62.5% | - | - |
| 🟢 Uncommon | 37.5% | - | - |
| 🔵 Rare | - | 64.3% | - |
| 🟣 Epic | - | 27.9% | 78% |
| 🟠 Legendary | - | 7.1% | 20% |
| 🌈 Mythic | - | 0.7% | 2% |