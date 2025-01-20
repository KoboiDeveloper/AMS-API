package rabbitmq

import (
	"encoding/json"

	"github.com/streadway/amqp"
)

type Email struct {
	To            string `json:"to"`
	Subject       string `json:"subject"`
	Body          string `json:"body"`
	MemberID      string `json:"memberID"`
	TransactionID string `json:"transactionID"`
}

type RabbitMQClient struct {
	Connection *amqp.Connection
	Channel    *amqp.Channel
	QueueName  string
}

// NewRabbitMQClient membuat instance baru RabbitMQClient
func NewRabbitMQClient(queueName, rabbitURL string) (*RabbitMQClient, error) {
	conn, err := amqp.Dial(rabbitURL)
	if err != nil {
		return nil, err
	}

	ch, err := conn.Channel()
	if err != nil {
		return nil, err
	}

	_, err = ch.QueueDeclare(
		queueName, // queue name
		true,      // durable
		false,     // delete when unused
		false,     // exclusive
		false,     // no-wait
		nil,       // arguments
	)
	if err != nil {
		return nil, err
	}

	return &RabbitMQClient{
		Connection: conn,
		Channel:    ch,
		QueueName:  queueName,
	}, nil
}

// PushEmail mengirim pesan email ke RabbitMQ
func (r *RabbitMQClient) PushEmail(email Email) error {
	message, err := json.Marshal(email)
	if err != nil {
		return err
	}

	return r.Channel.Publish(
		"",          // exchange
		r.QueueName, // routing key
		false,       // mandatory
		false,       // immediate
		amqp.Publishing{
			ContentType: "application/json",
			Body:        message,
		},
	)
}

// Close menutup koneksi RabbitMQ
func (r *RabbitMQClient) Close() {
	if r.Channel != nil {
		r.Channel.Close()
	}
	if r.Connection != nil {
		r.Connection.Close()
	}
}
