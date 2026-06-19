import Foundation

enum ParityFixtures {
    static let json = #"""
{
  "scenario": "baseline-shared-expenses",
  "users": [
    {
      "id": "user-alice",
      "name": "Alice Johnson",
      "email": "alice@example.com",
      "password": "password123",
      "image": null
    },
    {
      "id": "user-bob",
      "name": "Bob Smith",
      "email": "bob@example.com",
      "password": "password123",
      "image": null
    },
    {
      "id": "user-carol",
      "name": "Carol White",
      "email": "carol@example.com",
      "password": "password123",
      "image": null
    },
    {
      "id": "user-dave",
      "name": "Dave Brown",
      "email": "dave@example.com",
      "password": "password123",
      "image": null
    }
  ],
  "groups": [
    {
      "id": "group-nyc",
      "name": "NYC Trip",
      "description": "Summer trip to New York City",
      "currency": "USD",
      "category": "TRIP",
      "members": [
        {
          "userId": "user-alice",
          "role": "ADMIN",
          "joinedAt": "2024-07-01T00:00:00Z"
        },
        {
          "userId": "user-bob",
          "role": "MEMBER",
          "joinedAt": "2024-07-01T00:00:00Z"
        },
        {
          "userId": "user-carol",
          "role": "MEMBER",
          "joinedAt": "2024-07-01T00:00:00Z"
        }
      ]
    },
    {
      "id": "group-home",
      "name": "Our Apartment",
      "description": "Shared apartment expenses",
      "currency": "USD",
      "category": "HOME",
      "members": [
        {
          "userId": "user-alice",
          "role": "ADMIN",
          "joinedAt": "2024-08-01T00:00:00Z"
        },
        {
          "userId": "user-dave",
          "role": "MEMBER",
          "joinedAt": "2024-08-01T00:00:00Z"
        }
      ]
    }
  ],
  "expenses": [
    {
      "id": "expense-hotel",
      "description": "Hotel - 3 nights",
      "amount": 450,
      "currency": "USD",
      "date": "2024-07-10T00:00:00Z",
      "category": "accommodation",
      "groupId": "group-nyc",
      "paidById": "user-alice",
      "splitType": "EQUAL",
      "notes": null,
      "splits": [
        {
          "userId": "user-alice",
          "amount": 150,
          "percentage": null,
          "shares": null
        },
        {
          "userId": "user-bob",
          "amount": 150,
          "percentage": null,
          "shares": null
        },
        {
          "userId": "user-carol",
          "amount": 150,
          "percentage": null,
          "shares": null
        }
      ]
    },
    {
      "id": "expense-dinner",
      "description": "Dinner at Carbone",
      "amount": 180,
      "currency": "USD",
      "date": "2024-07-11T00:00:00Z",
      "category": "food",
      "groupId": "group-nyc",
      "paidById": "user-bob",
      "splitType": "EQUAL",
      "notes": null,
      "splits": [
        {
          "userId": "user-alice",
          "amount": 60,
          "percentage": null,
          "shares": null
        },
        {
          "userId": "user-bob",
          "amount": 60,
          "percentage": null,
          "shares": null
        },
        {
          "userId": "user-carol",
          "amount": 60,
          "percentage": null,
          "shares": null
        }
      ]
    },
    {
      "id": "expense-rent",
      "description": "August Rent",
      "amount": 2400,
      "currency": "USD",
      "date": "2024-08-01T00:00:00Z",
      "category": "housing",
      "groupId": "group-home",
      "paidById": "user-dave",
      "splitType": "EQUAL",
      "notes": null,
      "splits": [
        {
          "userId": "user-alice",
          "amount": 1200,
          "percentage": null,
          "shares": null
        },
        {
          "userId": "user-dave",
          "amount": 1200,
          "percentage": null,
          "shares": null
        }
      ]
    }
  ],
  "expectedDashboard": {
    "userId": "user-alice",
    "currency": "USD",
    "totalOwed": 240,
    "totalOwe": 1200,
    "balances": [
      {
        "userId": "user-bob",
        "amount": 90
      },
      {
        "userId": "user-carol",
        "amount": 150
      },
      {
        "userId": "user-dave",
        "amount": -1200
      }
    ]
  },
  "expectedGroupDebts": [
    {
      "groupId": "group-nyc",
      "debts": [
        {
          "fromId": "user-bob",
          "toId": "user-alice",
          "amount": 30
        },
        {
          "fromId": "user-carol",
          "toId": "user-alice",
          "amount": 210
        }
      ]
    }
  ]
}
"""#
}
