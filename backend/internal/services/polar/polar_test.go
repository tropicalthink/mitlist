package polar

import "testing"

// ListedPrice decides what number a customer is shown before they commit, so
// the selection rules matter more than most: showing an archived or non-fixed
// price would advertise something they will not be charged.
func TestListedPrice(t *testing.T) {
	str := func(s string) *string { return &s }

	tests := []struct {
		name    string
		product *Product
		want    int // -1 means "expect no price"
	}{
		{
			name:    "nil product",
			product: nil,
			want:    -1,
		},
		{
			name:    "no prices at all",
			product: &Product{Prices: nil},
			want:    -1,
		},
		{
			name: "single fixed price",
			product: &Product{Prices: []ProductPrice{
				{AmountType: AmountTypeFixed, PriceAmount: 1800, PriceCurrency: "eur"},
			}},
			want: 1800,
		},
		{
			name: "skips an archived price in favour of the live one",
			product: &Product{Prices: []ProductPrice{
				{AmountType: AmountTypeFixed, PriceAmount: 2500, IsArchived: true},
				{AmountType: AmountTypeFixed, PriceAmount: 1800},
			}},
			want: 1800,
		},
		{
			name: "ignores non-fixed amount types",
			product: &Product{Prices: []ProductPrice{
				{AmountType: "free", PriceAmount: 0},
				{AmountType: "custom", PriceAmount: 999},
				{AmountType: AmountTypeFixed, PriceAmount: 200, RecurringInterval: str("month")},
			}},
			want: 200,
		},
		{
			name: "every price archived yields nothing",
			product: &Product{Prices: []ProductPrice{
				{AmountType: AmountTypeFixed, PriceAmount: 1800, IsArchived: true},
			}},
			want: -1,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := tc.product.ListedPrice()
			if tc.want == -1 {
				if got != nil {
					t.Fatalf("expected no listed price, got %d", got.PriceAmount)
				}
				return
			}
			if got == nil {
				t.Fatalf("expected price %d, got none", tc.want)
			}
			if got.PriceAmount != tc.want {
				t.Fatalf("expected price %d, got %d", tc.want, got.PriceAmount)
			}
		})
	}
}
