import pytest


@pytest.fixture
def bruno_all_pass():
    return [
        {
            "results": [
                {
                    "path": "01-admin/Get Health",
                    "name": "Get Health",
                    "status": "pass",
                    "response": {"status": 200, "responseTime": 98},
                    "postResponseTestResults": [
                        {"description": "Status is 200", "status": "pass", "uid": "a"},
                        {"description": "Status is OK", "status": "pass", "uid": "b"},
                    ],
                    "testResults": [],
                    "preRequestTestResults": [],
                    "error": None,
                },
                {
                    "path": "02-models/List Models",
                    "name": "List Models",
                    "status": "pass",
                    "response": {"status": 200, "responseTime": 150},
                    "postResponseTestResults": [
                        {"description": "Status is 200", "status": "pass", "uid": "c"},
                    ],
                    "testResults": [],
                    "preRequestTestResults": [],
                    "error": None,
                },
            ]
        }
    ]


@pytest.fixture
def bruno_with_failures():
    return [
        {
            "results": [
                {
                    "path": "03-inference/Create Chat",
                    "status": "pass",
                    "response": {"status": 500, "responseTime": 200},
                    "postResponseTestResults": [
                        {
                            "description": "Status is 200",
                            "status": "fail",
                            "error": "expected 500 to deeply equal 200",
                        },
                        {"description": "Has choices", "status": "fail"},
                    ],
                    "testResults": [],
                    "preRequestTestResults": [],
                    "error": None,
                },
            ]
        }
    ]


@pytest.fixture
def bruno_with_error():
    return [
        {
            "results": [
                {
                    "path": "04-files/Create File",
                    "status": "fail",
                    "response": {"status": 0, "responseTime": 0},
                    "postResponseTestResults": [],
                    "testResults": [],
                    "preRequestTestResults": [],
                    "error": "ECONNREFUSED",
                },
            ]
        }
    ]


@pytest.fixture
def bruno_empty():
    return [{"results": []}]
