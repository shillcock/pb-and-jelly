# PocketBase JavaScript Hooks

This directory contains JavaScript files for extending PocketBase with custom server-side logic.

## How it works

- Files with `.pb.js` extension are automatically loaded by PocketBase
- Shared between dev and test environments (same code, different data)
- Deployed to production as part of your PocketBase setup

## File naming

- `main.pb.js` - Main hooks file (good starting point)
- `auth.pb.js` - Authentication-related hooks
- `api.pb.js` - Custom API routes
- `validation.pb.js` - Data validation hooks

## Common use cases

- **Custom API routes**: Add REST endpoints beyond collections
- **Event hooks**: React to record changes, auth events, etc.
- **Data validation**: Custom business logic validation
- **Email/notifications**: Send emails on specific events
- **CORS setup**: Handle cross-origin requests for frontend apps

## Documentation

- [PocketBase JS Overview](https://pocketbase.io/docs/js-overview/)
- [Event Hooks](https://pocketbase.io/docs/js-event-hooks/)
- [Custom Routes](https://pocketbase.io/docs/js-routing/)

## Example usage

```javascript
// Custom API route
routerAdd("GET", "/api/stats", (e) => {
    const userCount = $app.findCollectionByNameOrId("users").records().length
    return e.json(200, { users: userCount })
})

// React to user creation
onRecordAfterCreateRequest((e) => {
    // Send welcome email, create related records, etc.
    console.log("New user:", e.record.get("email"))
}, "users")
```