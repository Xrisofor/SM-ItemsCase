dofile( "$CONTENT_40639a2c-bb9f-4d4f-b88c-41bfe264ffa8/Scripts/ModDatabase.lua" )

RarityManager = class()

RarityManager.Settings = {
    Categories = {
        Block = "block",
        Part = "part",
        Tool = "tool",
    },
    Tiers = {
        {
            id = "common", 
            weight = 45.0,
            threshold = 0.45,
            blocks = { 64, 128 },
            parts = { 2, 5 }
        },
        {
            id = "uncommon",
            weight = 27.0,
            threshold = 0.72,
            blocks = { 32, 64 },
            parts = { 1, 3 }
        },
        {
            id = "rare",
            weight = 18.0,
            threshold = 0.90,
            blocks = { 24, 48 },
            parts = { 1, 2 }
        },
        {
            id = "epic",
            weight = 7.8,
            threshold = 0.97,
            blocks = { 16, 32 },
            parts = { 1, 1 }
        },
        {
            id = "legendary",
            weight = 2.0, 
            threshold = 0.995,
            blocks = { 10, 20 },
            parts = { 1, 1 }
        },
        {
            id = "mythic",
            weight = 0.2,
            threshold = 1.00,
            blocks = { 5, 10 },
            parts = { 1, 1 }
        },
    },
    DurabilityMap = {
        [0] = "common",
        [1] = "common", 
        [2] = "common",
        [3] = "uncommon",
        [4] = "uncommon",
        [5] = "rare",
        [6] = "rare",
        [7] = "epic",
        [8] = "epic",
        [9] = "legendary",
        [10] = "mythic",
    },
    Materials = {
        Metal = 5.0,
        Mechanical = 8.0,
        Electronics = 15.0,
        Glass = 3.0,
        Rock = 4.0,
        Wood = 2.0,
        Plastic = 1.5,
        Fence = 2.0,
        Cardboard = 0.5,
        Rubber = 3.0,
        Default = 1.0,
    },
    BenchFiles = {
        "dispenser",
        "hideout",
        "mininghubDispenser",
        "mininghubTrader",
        "portablecrafter",
        "sawtable",
        "workbench",
    }
}

local function categoryOf( uuid )
    local cats = RarityManager.Settings.Categories
    if sm.item.isBlock( uuid ) then return cats.Block end
    if sm.item.isTool( uuid ) then return cats.Tool end
    return cats.Part
end

local function getTierConfig( tierId )
    for _, tier in ipairs( RarityManager.Settings.Tiers ) do
        if tier.id == tierId then return tier end
    end
    return RarityManager.Settings.Tiers[1]
end

local function getTierByDurability( durability )
    durability = math.max( 1, math.min( 10, math.floor( durability or 1 ) ) )
    return RarityManager.Settings.DurabilityMap[durability] or RarityManager.Settings.Tiers[1].id
end

local recipes = nil
local valueCache = {}
local resolvingStack = {}
local cycleWarned = {}
local rarityBuckets = nil
local rarityByUuid = nil
local isBuilt = false

local function safeCall( fn, uuid, fallback )
    if not fn then return fallback end
    local ok, result = pcall( fn, uuid )
    return ( ok and result ~= nil ) and result or fallback
end

local function isUuidValid( uuid )
    return sm.shape.uuidExists( uuid ) or sm.tool.uuidExists( uuid )
end

local function tryOpenJson( path )
    local ok, data = pcall( sm.json.open, path )
    return ok and data or nil
end

local function getPhysicalValue( uuid )
    local size = safeCall( sm.item.getShapeSize, uuid, nil )
    local volume = size and math.max( 1.0, ( size.x or 1 ) * ( size.y or 1 ) * ( size.z or 1 ) ) or 1.0
    local material = safeCall( sm.item.getMaterial, uuid, "Default" )
    local matMult = RarityManager.Settings.Materials[material] or RarityManager.Settings.Materials.Default
    return volume * matMult
end

local function parseRecipes( list, target )
    if type( list ) ~= "table" then return end

    for _, recipe in ipairs( list ) do
        if type( recipe ) == "table" and recipe.itemId then
            local ok, outUuid = pcall( sm.uuid.new, recipe.itemId )
            if ok and isUuidValid( outUuid ) then
                local ingredients = {}
                for _, ing in ipairs( recipe.ingredientList or {} ) do
                    if type( ing ) == "table" and ing.itemId then
                        local ok2, ingUuid = pcall( sm.uuid.new, ing.itemId )
                        if ok2 and isUuidValid( ingUuid ) then
                            table.insert( ingredients, { uuid = ingUuid, quantity = ing.quantity or 1 } )
                        end
                    end
                end

                if #ingredients > 0 then
                    target[tostring( outUuid )] = {
                        quantity = recipe.quantity or 1,
                        ingredients = ingredients,
                    }
                end
            end
        end
    end
end

local function getAllLoadedMods()
    ModDatabase.unloadDescriptions(); ModDatabase.unloadShapesets(); ModDatabase.unloadToolsets()
    ModDatabase.loadDescriptions(); ModDatabase.loadShapesets(); ModDatabase.loadToolsets()

    local loadedMods = {}
    local descs = ModDatabase.databases.descriptions

    for localId, _ in pairs( ModDatabase.databases.shapesets ) do
        if ModDatabase.isModLoaded( localId ) then loadedMods[localId] = true end
    end
    for localId, _ in pairs( ModDatabase.databases.toolsets ) do
        if loadedMods[localId] == nil and ModDatabase.isModLoaded( localId ) then loadedMods[localId] = true end
    end
    for localId, _ in pairs( loadedMods ) do
        if descs[localId] and descs[localId].type == "Custom Game" then loadedMods[localId] = nil end
    end
    return loadedMods
end

local function collectRecipeRoots()
    local roots = { "$SURVIVAL_DATA/CraftingRecipes" }
    local ok, loadedMods = pcall( getAllLoadedMods )
    if ok and loadedMods then
        for localId, _ in pairs( loadedMods ) do
            table.insert( roots, "$CONTENT_" .. localId .. "/CraftingRecipes" )
        end
    end
    return roots
end

local vanillaKeys = nil
local function loadRecipesFromRoot( root, target )
    for _, bench in ipairs( RarityManager.Settings.BenchFiles ) do
        parseRecipes( tryOpenJson( root .. "/" .. bench .. ".json" ), target )
    end
    parseRecipes( tryOpenJson( root .. "/craftbot.json" ), target )

    local indexData = tryOpenJson( root .. "/craftbot/craftbot.json" )
    if type( indexData ) == "table" then
        for _, path in pairs( indexData ) do
            if type( path ) == "string" then parseRecipes( tryOpenJson( path ), target ) end
        end
    end
end

local function loadRecipes()
    recipes = {}
    local roots = collectRecipeRoots()
    loadRecipesFromRoot( roots[1], recipes )

    vanillaKeys = {}
    for key in pairs( recipes ) do vanillaKeys[key] = true end

    for i = 2, #roots do
        loadRecipesFromRoot( roots[i], recipes )
    end
end

function RarityManager.getItemValue( uuid )
    if not uuid or uuid:isNil() then return 1.0 end
    local key = tostring( uuid )
    if valueCache[key] then return valueCache[key] end

    if resolvingStack[key] then
        if not cycleWarned[key] then
            cycleWarned[key] = true
            sm.log.warning( string.format( "(Items Case) A cycle has been found in recipes for %s - a physical assessment is used", key ) )
        end
        return getPhysicalValue( uuid )
    end

    if not recipes then loadRecipes() end

    local recipe = recipes[key]
    local value = 0

    if recipe then
        resolvingStack[key] = true
        local totalCost = 0
        for _, ing in ipairs( recipe.ingredients ) do
            totalCost = totalCost + ( RarityManager.getItemValue( ing.uuid ) * ing.quantity )
        end
        resolvingStack[key] = nil
        value = totalCost / math.max( 1, recipe.quantity )
    else
        value = getPhysicalValue( uuid )
    end

    valueCache[key] = value
    return value
end

local function buildTierCutoffs( sortedPool )
    local total = #sortedPool
    local cutoffs = {}
    for _, tier in ipairs( RarityManager.Settings.Tiers ) do
        local index = math.max( 1, math.min( total, math.ceil( tier.threshold * total ) ) )
        cutoffs[tier.id] = sortedPool[index] and sortedPool[index].value or math.huge
    end
    return cutoffs
end

local function classify( value, cutoffs )
    for _, tier in ipairs( RarityManager.Settings.Tiers ) do
        if value <= cutoffs[tier.id] then return tier.id end
    end
    return RarityManager.Settings.Tiers[#RarityManager.Settings.Tiers].id
end

function RarityManager.build()
    if not recipes then loadRecipes() end

    local cats = RarityManager.Settings.Categories
    rarityBuckets = {}
    for _, cat in pairs( cats ) do
        rarityBuckets[cat] = {}
        for _, tier in ipairs( RarityManager.Settings.Tiers ) do
            rarityBuckets[cat][tier.id] = {}
        end
    end
    rarityByUuid = {}

    local overridden = {}
    if type( RARITY_OVERRIDES ) == "table" then
        for uuidStr, tier in pairs( RARITY_OVERRIDES ) do
            local ok, itemUuid = pcall( sm.uuid.new, uuidStr )
            if ok and isUuidValid( itemUuid ) then
                local category = categoryOf( itemUuid )
                tier = tostring( tier ):lower()
                if rarityBuckets[category][tier] then
                    table.insert( rarityBuckets[category][tier], uuidStr )
                    rarityByUuid[uuidStr] = tier
                    overridden[uuidStr] = true
                end
            end
        end
    end

    local partPool, vanillaPartPool = {}, {}

    for uuidStr, _ in pairs( recipes ) do
        if not overridden[uuidStr] then
            local ok, itemUuid = pcall( sm.uuid.new, uuidStr )
            if ok and isUuidValid( itemUuid ) then
                local category = categoryOf( itemUuid )

                if category == cats.Block then
                    local tier = getTierByDurability( safeCall( sm.item.getDurabilityRating, itemUuid, 1 ) )
                    table.insert( rarityBuckets[cats.Block][tier], uuidStr )
                    rarityByUuid[uuidStr] = tier

                elseif category == cats.Tool then
                    table.insert( rarityBuckets[cats.Tool]["epic"], uuidStr )
                    rarityByUuid[uuidStr] = "epic"

                else
                    local entry = { uuid = itemUuid, value = RarityManager.getItemValue( itemUuid ) }
                    table.insert( partPool, entry )
                    if vanillaKeys and vanillaKeys[uuidStr] then
                        table.insert( vanillaPartPool, entry )
                    end
                end
            end
        end
    end

    table.sort( vanillaPartPool, function( a, b ) return a.value < b.value end )
    local cutoffs = ( #vanillaPartPool > 0 ) and buildTierCutoffs( vanillaPartPool ) or nil
    if not cutoffs then
        table.sort( partPool, function( a, b ) return a.value < b.value end )
        cutoffs = buildTierCutoffs( partPool )
    end

    for _, entry in ipairs( partPool ) do
        local tier = classify( entry.value, cutoffs )
        local uuidStr = tostring( entry.uuid )
        table.insert( rarityBuckets[cats.Part][tier], uuidStr )
        rarityByUuid[uuidStr] = tier
    end

    isBuilt = true
end

local function ensureBuilt()
    if not isBuilt then RarityManager.build() end
end

function RarityManager.getRarity( uuid )
    ensureBuilt()
    local key = tostring( uuid )
    if rarityByUuid[key] then return rarityByUuid[key] end

    if sm.item.isTool( uuid ) then return "epic" end
    if sm.item.isBlock( uuid ) then
        return getTierByDurability( safeCall( sm.item.getDurabilityRating, uuid, 1 ) )
    end

    return RarityManager.Settings.Tiers[1].id
end

local function normalizeAllowedTiers( allowedTiers )
    if not allowedTiers then return nil end
    if type( allowedTiers ) == "string" then return { [string.lower( allowedTiers )] = true } end

    local set = {}
    for k, v in pairs( allowedTiers ) do
        local name = ( type( k ) == "number" and v ) or ( v == true and k )
        if type( name ) == "string" then set[string.lower( name )] = true end
    end
    return next( set ) and set or nil
end

local function itemsForTiers( category, allowedTiers )
    ensureBuilt()
    local filter = normalizeAllowedTiers( allowedTiers )
    local pool = {}

    for _, tier in ipairs( RarityManager.Settings.Tiers ) do
        if not filter or filter[tier.id] then
            local bucket = rarityBuckets[category][tier.id]
            if bucket then
                for _, uuidStr in ipairs( bucket ) do table.insert( pool, uuidStr ) end
            end
        end
    end
    return pool
end

local function buildWeightedTiers( category, allowedTiers )
    local weighted, totalWeight = {}, 0
    local filter = normalizeAllowedTiers( allowedTiers )

    for _, tier in ipairs( RarityManager.Settings.Tiers ) do
        if not filter or filter[tier.id] then
            local bucket = rarityBuckets[category][tier.id]
            if bucket and #bucket > 0 and tier.weight > 0 then
                table.insert( weighted, { tier = tier.id, weight = tier.weight } )
                totalWeight = totalWeight + tier.weight
            end
        end
    end
    return weighted, totalWeight
end

local function randomItems( category, count, allowedTiers )
    ensureBuilt()
    local weighted, totalWeight = buildWeightedTiers( category, allowedTiers )
    if #weighted == 0 or totalWeight <= 0 then return {} end

    local bucketMap = rarityBuckets[category]
    local result = {}

    for i = 1, count do
        local roll = math.random() * totalWeight
        local acc, chosenTier = 0, weighted[#weighted].tier

        for _, entry in ipairs( weighted ) do
            acc = acc + entry.weight
            if roll <= acc then
                chosenTier = entry.tier
                break
            end
        end

        local bucket = bucketMap[chosenTier]
        table.insert( result, bucket[ math.random( 1, #bucket ) ] )
    end
    return result
end

function RarityManager.getItemsForTiers( category, allowedTiers )
    return itemsForTiers( category, allowedTiers )
end

function RarityManager.getBlocksForTiers( allowedTiers )
    return itemsForTiers( RarityManager.Settings.Categories.Block, allowedTiers )
end

function RarityManager.getPartsForTiers( allowedTiers )
    return itemsForTiers( RarityManager.Settings.Categories.Part, allowedTiers )
end

function RarityManager.getToolsForTiers( allowedTiers )
    return itemsForTiers( RarityManager.Settings.Categories.Tool, allowedTiers )
end

function RarityManager.getRandom( category, count, allowedTiers )
    if type( count ) == "table" and allowedTiers == nil then
        allowedTiers, count = count, 35
    end

    return randomItems( category, tonumber( count ) or 35, allowedTiers )
end

function RarityManager.getRandomBlocks( count, allowedTiers )
    return RarityManager.getRandom( RarityManager.Settings.Categories.Block, count, allowedTiers )
end

function RarityManager.getRandomParts( count, allowedTiers )
    return RarityManager.getRandom( RarityManager.Settings.Categories.Part, count, allowedTiers )
end

function RarityManager.getRandomTools( count, allowedTiers )
    return RarityManager.getRandom( RarityManager.Settings.Categories.Tool, count, allowedTiers )
end

RarityManager.CategoryFetchers = {
    block = RarityManager.getRandomBlocks,
    part = RarityManager.getRandomParts,
    tool = RarityManager.getRandomTools,
}
RarityManager.Settings.CategoryFetchers = RarityManager.CategoryFetchers

function RarityManager.getItemQuantity( uuid )
    if type( uuid ) == "string" then uuid = sm.uuid.new( uuid ) end
    ensureBuilt()

    local category = categoryOf( uuid )
    if category == RarityManager.Settings.Categories.Tool then
        return 1
    end

    local tierConfig = getTierConfig( RarityManager.getRarity( uuid ) )
    local stackSize = safeCall( sm.item.getStackSize, uuid, math.huge )
    stackSize = ( type( stackSize ) == "number" and stackSize > 0 ) and stackSize or math.huge

    if category == RarityManager.Settings.Categories.Block then
        return math.min( math.random( tierConfig.blocks[1], tierConfig.blocks[2] ), stackSize )
    end

    local recipe = recipes and recipes[tostring( uuid )]
    if recipe and recipe.quantity and recipe.quantity > 1 then
        return math.min( recipe.quantity * math.random( 1, 3 ), stackSize )
    end

    return math.min( math.random( tierConfig.parts[1], tierConfig.parts[2] ), stackSize )
end

function RarityManager.clearCache()
    valueCache = {}
    resolvingStack = {}
    cycleWarned = {}
    rarityBuckets = nil
    rarityByUuid = nil
    recipes = nil
    vanillaKeys = nil
    isBuilt = false
end