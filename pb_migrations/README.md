# PocketBase JavaScript Migrations

This directory contains JavaScript migration files for managing database schema changes.

## How it works

- Files are executed in alphabetical order based on filename
- Use timestamp prefix (UNIX timestamp) for ordering
- Shared between dev and test environments
- Automatically applied when PocketBase starts

## File naming convention

- `{timestamp}_{description}.js` (e.g., `1700000000_create_posts.js`)
- Use UNIX timestamp for ordering (current: `date +%s`)
- Descriptive name for what the migration does

## Migration structure

```javascript
migrate((app) => {
    // Forward migration code
    // Create collections, modify schemas, etc.
}, (app) => {
    // Rollback migration code (optional)
    // Undo the changes made in forward migration
})
```

## Common patterns

### Creating a collection
```javascript
migrate((app) => {
    const collection = new Collection({
        name: "posts",
        type: "base",
        schema: [
            {
                name: "title",
                type: "text",
                required: true
            }
        ]
    })
    return app.save(collection)
})
```

### Modifying existing collection
```javascript
migrate((app) => {
    const collection = app.findCollectionByNameOrId("posts")
    // Modify collection.schema, rules, etc.
    return app.save(collection)
})
```

## Documentation

- [PocketBase JS Migrations](https://pocketbase.io/docs/js-migrations/)
- [Collection API](https://pocketbase.io/docs/js-collection-operations/)

## Tips

- Test migrations in dev environment first
- Always include rollback logic when possible
- Use descriptive migration names
- Don't modify existing migration files after deployment