# Commons recipe samples

Recipe cards and a cookbook page from Wikimedia Commons, used only to evaluate
reading recipes from photos (never for training). Each file keeps its original
license; images are 1600 px renditions or the original, whichever is smaller.

The expected drafts in `frontend/test/services/scan/recipe_text_parser_test.dart`
were transcribed from the photos by an AI assistant (Claude). The
`frontend/test/fixtures/recipes/*.ocr.json` files are what the on-device OCR
read from these photos (document mode), so the parser test runs without the
models; regenerate them when the OCR changes.

| File | Source | Author | License |
|---|---|---|---|
| `lemon_sponge_card.jpg` | [Lemon sponge cake recipe card - Michigan circa 1950.jpg](https://commons.wikimedia.org/wiki/File:Lemon_sponge_cake_recipe_card_-_Michigan_circa_1950.jpg) | SJW | CC BY-SA 4.0 |
| `pedernales_chili_card.jpg` | [Recipe Card for Pedernales River Chili - DPLA - 3d1051a803e0ab4b9f54b5aada0409ed.jpg](https://commons.wikimedia.org/wiki/File:Recipe_Card_for_Pedernales_River_Chili_-_DPLA_-_3d1051a803e0ab4b9f54b5aada0409ed.jpg) | U.S. National Archives and Records Administration | Public domain |
| `rumford_apricot_page.jpg` | [Rumford Fruit Recipes - DPLA - 89eeb36024005508fe3938bff37d3ec4 (page 9).jpg](https://commons.wikimedia.org/wiki/File:Rumford_Fruit_Recipes_-_DPLA_-_89eeb36024005508fe3938bff37d3ec4_(page_9).jpg) | Lily Haxworth Wallace | Public domain |
| `pound_cake_handwritten.jpg` | [Pound cake recipe card - Handwritten 2024-05-21 103943 page 1.jpg](https://commons.wikimedia.org/wiki/File:Pound_cake_recipe_card_-_Handwritten_2024-05-21_103943_page_1.jpg) | SJGW | CC BY-SA 4.0 |
