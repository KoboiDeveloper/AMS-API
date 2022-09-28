package entities

type Product struct {
	ID          uint    `gorm:"primary_key;auto_increment" json:"id"`
	Name        string  `gorm:"size:255;not null;unique"   json:"nickname"`
	Price       float64 `gorm:"size:255;not null;unique"   json:"price"`
	Description string  `gorm:"size:255;not null;unique"   json:"description"`
}