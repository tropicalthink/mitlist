# Commons receipt samples

Real till receipts from Wikimedia Commons, used only to evaluate receipt
reading (never for training). Each file keeps its original license; images are
the renditions Commons serves (1920 px or the original, whichever is smaller).

Ground truth in `frontend/test/fixtures/receipts/manifest.json` was
transcribed from the photos by an AI assistant (Claude) and checked against
each receipt's own arithmetic: on every receipt the transcribed lines add up
to the printed total. The `*.ocr.json` files beside it are what the on-device
OCR read from these photos (document mode), so the parser test runs without
the models; regenerate them when the OCR changes.

| File | Source | Author | License |
|---|---|---|---|
| `aldi_2006.jpg` | [Aldi-Quittung-2006.jpg](https://commons.wikimedia.org/wiki/File:Aldi-Quittung-2006.jpg) | Riquix | CC BY-SA 4.0 |
| `lidl_aurich_2019.jpg` | [Lidl Emsstraße receipt, Aurich (2019) 01.jpg](https://commons.wikimedia.org/wiki/File:Lidl_Emsstra%C3%9Fe_receipt,_Aurich_(2019)_01.jpg) | Donald Trung Quoc Don | CC BY-SA 4.0 |
| `tesco_1994.jpg` | [Tesco grocery receipt Finchley 1994.jpg](https://commons.wikimedia.org/wiki/File:Tesco_grocery_receipt_Finchley_1994.jpg) | Tesco | Public domain |
| `savemart_2010.jpg` | [Save Mart recipt 2010-10-23.jpg](https://commons.wikimedia.org/wiki/File:Save_Mart_recipt_2010-10-23.jpg) | Amin Eshaiker | Public domain |
| `woolworths.jpg` | [Receipt-woolworth.jpg](https://commons.wikimedia.org/wiki/File:Receipt-woolworth.jpg) | Daryldaryl | CC BY-SA 4.0 |
| `italian_iva.jpg` | [Italian supermarket receipt showing value-added tax (IVA) categories.jpg](https://commons.wikimedia.org/wiki/File:Italian_supermarket_receipt_showing_value-added_tax_(IVA)_categories.jpg) | Sgroey | CC BY-SA 4.0 |
