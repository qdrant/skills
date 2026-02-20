# Filtering Reference

Complete reference for Qdrant filter conditions in the TypeScript/JS SDK.

Filters are plain JavaScript objects. No model classes or imports needed.

## Filter Structure

Filters combine conditions with boolean logic:

```typescript
const filter = {
    must: [...],        // AND: all conditions must match
    should: [...],      // OR: at least one must match
    must_not: [...],    // NOT: none can match
};
```

## Match Conditions

### Exact match (keyword/integer/boolean)

```typescript
{ key: 'city', match: { value: 'Berlin' } }
{ key: 'count', match: { value: 42 } }
{ key: 'active', match: { value: true } }
```

### Match any (IN)

```typescript
{ key: 'color', match: { any: ['red', 'blue', 'green'] } }
```

### Match except (NOT IN)

```typescript
{ key: 'status', match: { except: ['deleted', 'archived'] } }
```

### Full-text match

```typescript
{ key: 'description', match: { text: 'vector database' } }
```

Requires a `text` payload index on the field.

## Range Conditions

```typescript
{ key: 'price', range: { gte: 10.0, lte: 100.0 } }
{ key: 'count', range: { gt: 0 } }
```

Available operators: `gt`, `gte`, `lt`, `lte`.

## Datetime Filtering

```typescript
{
    key: 'created_at',
    range: {
        gte: '2024-01-01T00:00:00Z',
        lt: '2025-01-01T00:00:00Z',
    },
}
```

Requires a `datetime` payload index.

## Geo Conditions

### Bounding box

```typescript
{
    key: 'location',
    geo_bounding_box: {
        top_left: { lat: 52.52, lon: 13.35 },
        bottom_right: { lat: 52.50, lon: 13.45 },
    },
}
```

### Radius

```typescript
{
    key: 'location',
    geo_radius: {
        center: { lat: 52.52, lon: 13.405 },
        radius: 1000.0,  // meters
    },
}
```

### Polygon

```typescript
{
    key: 'location',
    geo_polygon: {
        exterior: {
            points: [
                { lat: 52.52, lon: 13.35 },
                { lat: 52.52, lon: 13.45 },
                { lat: 52.50, lon: 13.45 },
                { lat: 52.50, lon: 13.35 },
                { lat: 52.52, lon: 13.35 },  // close the polygon
            ],
        },
    },
}
```

## Nested Filters

Filter on nested object fields using dot notation:

```typescript
{ key: 'address.city', match: { value: 'Berlin' } }
```

For arrays of objects, use `nested`:

```typescript
{
    nested: {
        key: 'reviews',
        filter: {
            must: [
                { key: 'reviews[].score', range: { gte: 4 } },
                { key: 'reviews[].verified', match: { value: true } },
            ],
        },
    },
}
```

## Null and Empty Checks

### Field is null

```typescript
{ is_null: { key: 'email' } }
```

### Field is empty (empty array)

```typescript
{ is_empty: { key: 'tags' } }
```

## Has ID Filter

Filter by point IDs:

```typescript
{ has_id: [1, 2, 3] }
```

## Combining Filters

Nested boolean logic:

```typescript
{
    must: [
        { key: 'category', match: { value: 'electronics' } },
    ],
    should: [
        { key: 'brand', match: { value: 'Apple' } },
        { key: 'brand', match: { value: 'Samsung' } },
    ],
    must_not: [
        { key: 'discontinued', match: { value: true } },
    ],
}
```

This matches: category IS electronics AND (brand IS Apple OR brand IS Samsung) AND discontinued IS NOT true.

## min_should

Require at least N `should` conditions to match:

```typescript
{
    should: [
        { key: 'tag', match: { value: 'fast' } },
        { key: 'tag', match: { value: 'cheap' } },
        { key: 'tag', match: { value: 'reliable' } },
    ],
    min_should: { conditions: [], min_count: 2 },
}
```
