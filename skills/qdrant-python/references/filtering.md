# Filtering Reference

Complete reference for Qdrant filter conditions in the Python SDK.

## Filter Structure

Filters combine conditions with boolean logic:

```python
from qdrant_client.models import Filter, FieldCondition, MatchValue, Range

query_filter = Filter(
    must=[...],        # AND: all conditions must match
    should=[...],      # OR: at least one must match
    must_not=[...],    # NOT: none can match
)
```

## Match Conditions

### Exact match (keyword/integer)

```python
FieldCondition(key="city", match=MatchValue(value="Berlin"))
```

### Match any (IN)

```python
FieldCondition(key="color", match=MatchAny(any=["red", "blue", "green"]))
```

### Match except (NOT IN)

```python
FieldCondition(key="status", match=MatchExcept(except_=["deleted", "archived"]))
```

### Full-text match

```python
FieldCondition(key="description", match=MatchText(text="vector database"))
```

Requires a `text` payload index on the field.

## Range Conditions

```python
FieldCondition(key="price", range=Range(gte=10.0, lte=100.0))
FieldCondition(key="count", range=Range(gt=0))
```

Available operators: `gt`, `gte`, `lt`, `lte`.

## Datetime Filtering

```python
FieldCondition(
    key="created_at",
    range=DatetimeRange(
        gte="2024-01-01T00:00:00Z",
        lt="2025-01-01T00:00:00Z",
    ),
)
```

Requires a `datetime` payload index.

## Geo Conditions

### Bounding box

```python
FieldCondition(
    key="location",
    geo_bounding_box=GeoBoundingBox(
        top_left=GeoPoint(lat=52.52, lon=13.35),
        bottom_right=GeoPoint(lat=52.50, lon=13.45),
    ),
)
```

### Radius

```python
FieldCondition(
    key="location",
    geo_radius=GeoRadius(
        center=GeoPoint(lat=52.52, lon=13.405),
        radius=1000.0,  # meters
    ),
)
```

### Polygon

```python
FieldCondition(
    key="location",
    geo_polygon=GeoPolygon(
        exterior=GeoLineString(points=[
            GeoPoint(lat=52.52, lon=13.35),
            GeoPoint(lat=52.52, lon=13.45),
            GeoPoint(lat=52.50, lon=13.45),
            GeoPoint(lat=52.50, lon=13.35),
            GeoPoint(lat=52.52, lon=13.35),  # close the polygon
        ]),
    ),
)
```

## Nested Filters

Filter on nested object fields using dot notation:

```python
FieldCondition(key="address.city", match=MatchValue(value="Berlin"))
```

For arrays of objects, use `nested`:

```python
from qdrant_client.models import NestedCondition, Nested

Filter(must=[
    NestedCondition(
        nested=Nested(
            key="reviews",
            filter=Filter(must=[
                FieldCondition(key="reviews[].score", range=Range(gte=4)),
                FieldCondition(key="reviews[].verified", match=MatchValue(value=True)),
            ]),
        )
    )
])
```

## Null and Empty Checks

### Field exists (is not null)

```python
from qdrant_client.models import IsNullCondition, PayloadField

Filter(must_not=[
    IsNullCondition(is_null=PayloadField(key="email"))
])
```

### Field is empty (empty array)

```python
from qdrant_client.models import IsEmptyCondition

Filter(must_not=[
    IsEmptyCondition(is_empty=PayloadField(key="tags"))
])
```

## Has ID Filter

Filter by point IDs:

```python
from qdrant_client.models import HasIdCondition

Filter(must=[
    HasIdCondition(has_id=[1, 2, 3])
])
```

## Combining Filters

Nested boolean logic:

```python
Filter(
    must=[
        FieldCondition(key="category", match=MatchValue(value="electronics")),
    ],
    should=[
        FieldCondition(key="brand", match=MatchValue(value="Apple")),
        FieldCondition(key="brand", match=MatchValue(value="Samsung")),
    ],
    must_not=[
        FieldCondition(key="discontinued", match=MatchValue(value=True)),
    ],
)
```

This matches: category IS electronics AND (brand IS Apple OR brand IS Samsung) AND discontinued IS NOT true.
