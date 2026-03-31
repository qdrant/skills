# Cognee + Qdrant

Docs: [Cognee](https://qdrant.tech/documentation/frameworks/cognee/)

## Run

`python3 commands/cognee.py`

## Snippet

```python
import os,pathlib
import asyncio

import cognee
from cognee_community_vector_adapter_qdrant import register 
from constant import MY_PREFERENCE

from dotenv import load_dotenv
load_dotenv()

system_path = pathlib.Path(__file__).parent
cognee.config.system_root_directory(os.path.join(system_path, ".cognee_system"))
cognee.config.data_root_directory(os.path.join(system_path, ".data_storage"))

cognee.config.set_relational_db_config(
    {
        "db_provider": "sqlite",
    }
)
cognee.config.set_vector_db_config({
    "vector_db_provider": "qdrant",
    "vector_db_url": os.getenv("QDRANT_API_URL", "http://localhost:6333"),
    "vector_db_key": os.getenv("QDRANT_API_KEY", ""),
    "vector_dataset_database_handler":"qdrant"
})

async def main():
    await cognee.prune.prune_data()
    await cognee.prune.prune_system(metadata=True)

    await cognee.add(MY_PREFERENCE,node_set="personal_tarun")
    await cognee.add("- In Food I usually prefer Thali and Indian Vegetarian food places",node_set=["food"])

    await cognee.cognify()
    await cognee.memify()

    results = await cognee.search("plan 3 days Itinerary for Rome based on my preference")

    for result in results:
        print(result)

if __name__ == '__main__':
    asyncio.run(main())
```
