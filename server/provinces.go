package main

// Generated from Vietnamese 2025 province boundaries (simplified).

var RegionNames = []string{"Miền Bắc", "Bắc Trung Bộ", "Duyên hải Trung Bộ", "Tây Nguyên", "Đông Nam Bộ", "ĐBSCL"}

type ProvinceDef struct {
	Name    string
	Region  int
	Tax     int64
	Defense int
}

var Provinces = []ProvinceDef{
	{"Hà Nội", 0, 74, 123},
	{"Hải Phòng", 0, 47, 93},
	{"Quảng Ninh", 0, 25, 71},
	{"Bắc Ninh", 0, 40, 80},
	{"Hưng Yên", 0, 39, 91},
	{"Ninh Bình", 0, 45, 87},
	{"Phú Thọ", 0, 42, 83},
	{"Thái Nguyên", 0, 27, 75},
	{"Lạng Sơn", 0, 21, 72},
	{"Cao Bằng", 0, 19, 68},
	{"Tuyên Quang", 0, 28, 87},
	{"Lào Cai", 0, 27, 86},
	{"Lai Châu", 0, 19, 73},
	{"Điện Biên", 0, 20, 74},
	{"Sơn La", 0, 25, 87},
	{"Thanh Hóa", 1, 44, 86},
	{"Nghệ An", 1, 41, 96},
	{"Hà Tĩnh", 1, 26, 70},
	{"Quảng Trị", 1, 28, 84},
	{"Huế", 1, 25, 69},
	{"Đà Nẵng", 2, 36, 85},
	{"Quảng Ngãi", 2, 30, 90},
	{"Khánh Hòa", 2, 30, 77},
	{"Đắk Lắk", 3, 38, 99},
	{"Gia Lai", 3, 39, 107},
	{"Lâm Đồng", 3, 41, 113},
	{"Hồ Chí Minh", 4, 80, 120},
	{"Đồng Nai", 4, 45, 89},
	{"Tây Ninh", 4, 37, 80},
	{"Cần Thơ", 5, 43, 81},
	{"An Giang", 5, 49, 86},
	{"Cà Mau", 5, 29, 72},
	{"Vĩnh Long", 5, 44, 82},
}
