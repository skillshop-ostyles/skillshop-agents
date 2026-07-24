// GOOD: well-defined tool with descriptions and enums
const getUser = {
    name: "get_user",
    description: "Get user details by ID",
    parameters: {
        type: "object",
        properties: {
            user_id: {
                type: "string",
                description: "The unique UUID of the user",
                format: "uuid"
            }
        },
        required: ["user_id"]
    }
};

// BAD: missing parameter description - model guesses format
const searchProducts = {
    name: "search_products",
    description: "Search products by query",
    parameters: {
        type: "object",
        properties: {
            query: { type: "string" },
            category: { type: "string" },
            price_range: { type: "string" }
        }
    }
};

// BAD: object type without properties - model invents keys
const updateSettings = {
    name: "update_settings",
    description: "Update user settings",
    parameters: {
        type: "object",
        properties: {
            settings: { type: "object" },
            options: { type: "object" }
        }
    }
};
