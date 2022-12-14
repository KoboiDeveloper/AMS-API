package main

import (
	"log"

	"github.com/spf13/viper"
)

type Config struct {
	Port             string `mapstructure:"port"`
	ConnectionString string `mapstructure:"connection_string"`
}

var AppConfig *Config

func LoadAppConfig() {
	log.Println("Loading Server Configurations...")
	viper.AddConfigPath("./configs/")
	viper.SetConfigName("confuck") // Register config file name (no extension)
	viper.SetConfigType("json")    // Look for specific type

	err := viper.ReadInConfig()

	if err != nil {
		log.Fatal(err)
	}
	err = viper.Unmarshal(&AppConfig)
	if err != nil {
		log.Fatal(err)
	}
}
