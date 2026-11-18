---
name: qdrant-relevance-feedback
description: "Expanding the candidate pool via relevance feedback, as an alternative to reranking when a dense retriever is too weak. Use when someone asks about 'Qdrant's Relevance Feedback API', 'improving dense search relevance/recall', 'how to discover/get more relevant results from vector search', 'cheaper/better alternative to reranking', 'using a more heavy/big embedding model for dense search but can't afford it', 'finding more relevant documents beyond the initial search pool', or 'feedback loops'. Also trigger when the user has a search quality problem due to a dense retriever being weak and is considering reranking as a solution — this API may be a better fit"
---

Reranking reorders documents that have already been retrieved. Qdrant's Relevance Feedback (RF), available since **v1.17**, instead modifies the vector search process itself based on a small amount of reranker feedback, distilling reranker (feedback model) knowledge into the search step. This allows RF to surface documents that the initial ANN search did not score highly enough.

The RF is intended for tasks where relevance correlates with similarity in vector space. It is available as of Qdrant 1.17.

Read this whole skill before implementing: pick the usage pattern that matches the user's goal, and check the What NOT to Do list.

## How It Works

A relevance feedback query takes the query (`target`), a few seed documents (`feedback`) scored by a feedback model (3-5 seeds is enough), and formula weights for the `naive` strategy. See [Relevance Feedback](https://skills.qdrant.tech/md/documentation/search/search-relevance/?s=relevance-feedback) for the request format.

The formula weights MUST be trained once per general search use case (your dataset, dense retriever, and feedback model). If you do not train them, results will at best be random and will not align with your data distribution or model behavior. Training is lightweight because the formula itself is simple.

During search, it scores each candidate by combining similarity to the original query, similarity to highly rated seed documents and dissimilarity to poorly rated ones.

### Feedback Model

A **feedback model** is any model that can produce a float relevance score for `(query, document)` pairs. Higher scores must always mean higher relevance.

Examples: a cross-encoder, embedding similarity (for example, cosine similarity between query and document embeddings, or max_sim for late interaction models), an LLM-based scorer, a custom ranker.

The feedback model used during training and inference MUST be the same model. Formula weights during training are calibrated to that model's score distribution. If you switch feedback models, you must retrain.

**What is a Good Feedback Model:**
- If the model does not improve ranking quality when used as a reranker on retrieved documents,  the RF search will not have a meaningful signal to amplify.
- RF search quality depends heavily on how well the feedback model scores partial matches. The training loss of RF formula relies on relative ordering, so poor score separation in the middle range (documents that are neither clearly relevant nor clearly irrelevant) weakens results.

### To Make the RF API Work, You Need to Calibrate Weights First

Use when: setting up RF for a new use case — a new collection, feedback model, or embedding model powering ANN search.

RF uses a weighted formula that combines the original query vector with feedback signals.

For the currently available `naive` strategy, the learned weights control:
- `a` — how much to trust the original ANN query-document similarity
- `b` — how strongly differences in feedback scores matter
- `c` — how strongly to follow the feedback direction (toward relevant documents and away from irrelevant ones)

These weights must be learned from your data before use. You cannot safely use arbitrary values.

- Train the weights with the [qdrant-relevance-feedback](https://pypi.org/project/qdrant-relevance-feedback/) Python library, following the [Training](https://skills.qdrant.tech/md/documentation/tutorials-search-engineering/using-relevance-feedback/?s=training) walkthrough. Use the same retriever and feedback model you will use at inference.
- Train on 50-300 representative queries. Prefer real queries from the user's traffic; if there are none, generate representative queries for the use case and tell the user, and give them the option to provide their own.
- Inform the user on cost and quality trade-offs of training: the feedback model scores every training query × `limit` candidates.
- Check the train metrics, which show whether RF had a signal (disagreement between retriever and feedback model) to distill and learn from. If there was no signal, adapt training parameters, queries, or the feedback model, and retrain until RF learns well.
- Store the resulting RF parameters in your configuration and use them during inference. Retrain if your query distribution or corpus changes significantly.
- Evaluate the formula on a separate test set of representative queries before production, as in the tutorial's [Evaluation](https://skills.qdrant.tech/md/documentation/tutorials-search-engineering/using-relevance-feedback/?s=evaluation) section. If results seem unsatisfactory, try: adjusting `limit` to retrieve more candidates during training, changing the feedback model, or curating a more representative query set.

## Building the Query

Check the [Relevance Feedback](https://skills.qdrant.tech/md/documentation/search/search-relevance/?s=relevance-feedback) documentation and study the code and methods of the relevant SDK before filling in any field. For both patterns below:

- Set `using` to the retriever's vector name: RF operates in the retriever's vector space.
- Set `target` to the query embedding from the retriever (Qdrant Cloud Inference also works).
- Use the `naive` strategy with your calibrated weights.
- A point ID in a feedback `example` excludes that document from the results. A stored vector in `example` instead can keep the document in the results.

## Want High-Quality Top-1/3 Results at Reasonable Cost

Use when: top-1 or top-3 precision matters most, and reranking a large pool of documents would be too expensive or slow. This pattern below can match reranking quality at the top of the ranking for semantic similarity tasks, but it performs worse at deeper cutoffs. Do not use this approach when top-10+ recall is the priority.

Only score a small set of seed documents. Five seeds is a robust default across many task types and scoring them costs user roughly 5× less than reranking a 25-document pool.

- Retrieve the top 5 documents using ANN search and score them with the feedback model used in training. These become the feedback seeds.
- Send each seed's stored vector (same embedding model as `target`) as its `example`, with its feedback score.
- Set `limit` to the number of final results you need, and use the RF results directly as final results.

## Want to Find Relevant Documents Beyond the Initial Search Results

Use when: recall matters more than latency or cost (research, legal, medical, compliance), and relevant documents may exist outside the initial ANN retrieval pool.

It performs two feedback model scoring rounds:
1. on feedback seeds
2. on newly surfaced RF results

The second reranking pass safely promotes newly discovered documents into the top-10 of the final ranking. The advantage over standard reranking is that RF can reach relevant documents that lie completely outside the initial ANN pool, while a reranker with the same budget cannot. The tradeoff is higher latency due to two rounds of feedback-model scoring.

- Retrieve and score 5 seed documents, and send each seed's point ID as its `example`, with its feedback score.
- Set `limit` to the number of results the user can afford to rerank. The total scoring cost covers both the seeds and the RF results, roughly equivalent to reranking a pool of the same combined size. Inform and consult with the user.
- Score the returned RF results with your feedback model, merge them with the original seeds, and sort by feedback score. These are your final results.

## What NOT to Do

- Do not skip calibration and use random formula weights. Untrained weights produce arbitrary results. (`a=1, b=0, c=0` can be used if you only want vanilla ANN behavior through the RF API.)
- Do not use the RF API on sparse vectors. The formula operates in continuous vector space where direction between points has geometric meaning -- sparse representations do not preserve this property.
- Do not use a feedback model where higher scores mean lower relevance. Scores must be monotonic: higher = more relevant.
- Do not use fewer than 2 feedback seeds. A single seed provides no contrastive signal. The formula needs at least one relatively more relevant and one relatively less relevant example to establish direction. Two is the minimum; five is the recommended default.
- Do not use significantly more than 5 seeds expecting better quality. Additional seeds usually add noise and increase scoring cost without meaningful gains.
- Do not use a different feedback model during inference than the one used during calibration. The learned weights are tied to that model's score scale and distribution.
- Do not use a feedback model that does not improve retrieval quality as a standard reranker on your data.
- Do not proceed to inference if training and evaluation metrics of qdrant-relevance-feedback package demonstrated unsatisfactory results, instead find a good training set of representative queries, a feedback model providing a meaningful signal and effective train parameters.
