"""Unit tests for backend.db (prescriptions). Mock _conn so no real PostgreSQL is required."""

import unittest.mock as mock

import backend.db as db_module


# --- _row_to_prescription (no mock needed) ---


def test_row_to_prescription_maps_tuple_to_camelCase_dict():
    """_row_to_prescription maps a 7-tuple to API prescription dict with camelCase keys."""
    row = (
        "RX-1",
        "patient-1",
        "device-1",
        "Therapy A",
        1000,
        2000,
        '[{"name":"flow","value":1.0}]',
    )
    out = db_module._row_to_prescription(row)
    assert out == {
        "prescriptionId": "RX-1",
        "patientId": "patient-1",
        "deviceId": "device-1",
        "medicationOrTherapy": "Therapy A",
        "startDate": 1000,
        "endDate": 2000,
        "parameters": '[{"name":"flow","value":1.0}]',
    }


def test_row_to_prescription_uses_empty_list_when_parameters_is_none():
    """_row_to_prescription uses '[]' when parameters (index 6) is None."""
    row = ("id", "p", "d", "med", None, None, None)
    out = db_module._row_to_prescription(row)
    assert out["parameters"] == "[]"


# --- get_prescriptions_from_db ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_get_prescriptions_from_db_returns_none_when_no_connection(_conn_mock):
    """When _conn returns None, get_prescriptions_from_db returns None."""
    assert db_module.get_prescriptions_from_db() is None
    _conn_mock.assert_called_once()


@mock.patch.object(db_module, "_conn")
def test_get_prescriptions_from_db_returns_list_when_rows_returned(_conn_mock):
    """When cursor returns rows, get_prescriptions_from_db returns list of prescription dicts."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.fetchall.return_value = [
        ("rx-1", "p1", "d1", "med1", 1, 2, "[]"),
        ("rx-2", "p2", "d2", "med2", 3, 4, "[]"),
    ]
    _conn_mock.return_value = mock_conn

    result = db_module.get_prescriptions_from_db()
    assert result is not None
    assert len(result) == 2
    assert result[0]["prescriptionId"] == "rx-1" and result[0]["patientId"] == "p1"
    assert result[1]["prescriptionId"] == "rx-2" and result[1]["patientId"] == "p2"
    mock_conn.close.assert_called_once()


# --- get_prescription_by_id ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_get_prescription_by_id_returns_none_when_no_connection(_conn_mock):
    """When _conn returns None, get_prescription_by_id returns None."""
    assert db_module.get_prescription_by_id("RX-1") is None


@mock.patch.object(db_module, "_conn")
def test_get_prescription_by_id_returns_none_when_not_found(_conn_mock):
    """When cursor fetchone returns None, get_prescription_by_id returns None."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.fetchone.return_value = None
    _conn_mock.return_value = mock_conn

    assert db_module.get_prescription_by_id("nonexistent") is None
    mock_conn.close.assert_called_once()


@mock.patch.object(db_module, "_conn")
def test_get_prescription_by_id_returns_dict_when_found(_conn_mock):
    """When cursor fetchone returns a row, get_prescription_by_id returns prescription dict."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.fetchone.return_value = ("RX-A", "p1", "d1", "med", 10, 20, "[]")
    _conn_mock.return_value = mock_conn

    result = db_module.get_prescription_by_id("RX-A")
    assert result is not None
    assert result["prescriptionId"] == "RX-A" and result["patientId"] == "p1"


# --- create_prescription ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_create_prescription_returns_none_when_no_connection(_conn_mock):
    """When _conn returns None, create_prescription returns None."""
    row = {"patientId": "p1", "deviceId": "d1", "medicationOrTherapy": "", "parameters": "[]"}
    assert db_module.create_prescription(row) is None


@mock.patch.object(db_module, "get_prescription_by_id")
@mock.patch.object(db_module, "_conn")
def test_create_prescription_returns_created_dict_when_success(_conn_mock, get_by_id_mock):
    """When insert succeeds, create_prescription returns result of get_prescription_by_id."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    _conn_mock.return_value = mock_conn
    get_by_id_mock.return_value = {
        "prescriptionId": "RX-d1-aB3c",
        "patientId": "p1",
        "deviceId": "d1",
        "medicationOrTherapy": "",
        "startDate": None,
        "endDate": None,
        "parameters": "[]",
    }

    row = {
        "patientId": "p1",
        "deviceId": "d1",
        "medicationOrTherapy": "",
        "startDate": None,
        "endDate": None,
        "parameters": "[]",
    }
    result = db_module.create_prescription(row)
    assert result is not None
    assert result["prescriptionId"] == "RX-d1-aB3c"
    mock_cursor.execute.assert_called_once()
    mock_conn.commit.assert_called_once()
    get_by_id_mock.assert_called_once()
    # prescription_id passed to get_prescription_by_id should start with RX- and contain d1
    call_args = get_by_id_mock.call_args[0][0]
    assert call_args.startswith("RX-") and "d1" in call_args


# --- update_prescription ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_update_prescription_returns_none_when_no_connection(_conn_mock):
    """When _conn returns None, update_prescription returns None."""
    assert db_module.update_prescription("RX-1", {"patientId": "p2"}) is None


@mock.patch.object(db_module, "get_prescription_by_id")
@mock.patch.object(db_module, "_conn")
def test_update_prescription_returns_none_when_not_found(_conn_mock, get_by_id_mock):
    """When prescription does not exist, update_prescription returns None."""
    mock_conn = mock.MagicMock()
    _conn_mock.return_value = mock_conn
    get_by_id_mock.return_value = None

    assert db_module.update_prescription("RX-nonexistent", {"patientId": "p2"}) is None
    mock_conn.close.assert_called_once()


@mock.patch.object(db_module, "get_prescription_by_id")
@mock.patch.object(db_module, "_conn")
def test_update_prescription_returns_updated_dict_when_success(_conn_mock, get_by_id_mock):
    """When update succeeds, update_prescription returns updated prescription dict."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    _conn_mock.return_value = mock_conn
    existing = {
        "prescriptionId": "RX-1",
        "patientId": "p1",
        "deviceId": "d1",
        "medicationOrTherapy": "med",
        "startDate": 1,
        "endDate": 2,
        "parameters": "[]",
    }
    get_by_id_mock.side_effect = [existing, {**existing, "patientId": "p2"}]

    result = db_module.update_prescription("RX-1", {"patientId": "p2"})
    assert result is not None
    assert result["patientId"] == "p2"
    mock_cursor.execute.assert_called_once()
    mock_conn.commit.assert_called_once()


# --- delete_prescription ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_delete_prescription_returns_false_when_no_connection(_conn_mock):
    """When _conn returns None, delete_prescription returns False."""
    assert db_module.delete_prescription("RX-1") is False


@mock.patch.object(db_module, "_conn")
def test_delete_prescription_returns_false_when_not_found(_conn_mock):
    """When no row is deleted (rowcount 0), delete_prescription returns False."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.rowcount = 0
    _conn_mock.return_value = mock_conn

    assert db_module.delete_prescription("RX-nonexistent") is False
    mock_conn.commit.assert_called_once()


@mock.patch.object(db_module, "_conn")
def test_delete_prescription_returns_true_when_deleted(_conn_mock):
    """When a row is deleted (rowcount > 0), delete_prescription returns True."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.rowcount = 1
    _conn_mock.return_value = mock_conn

    assert db_module.delete_prescription("RX-1") is True
    mock_cursor.execute.assert_called_once()
    mock_conn.commit.assert_called_once()


# --- count_prescriptions ---


@mock.patch.object(db_module, "_conn", return_value=None)
def test_count_prescriptions_returns_minus_one_when_no_connection(_conn_mock):
    """When _conn returns None, count_prescriptions returns -1."""
    assert db_module.count_prescriptions() == -1


@mock.patch.object(db_module, "_conn")
def test_count_prescriptions_returns_count_when_success(_conn_mock):
    """When cursor returns a count, count_prescriptions returns it."""
    mock_conn = mock.MagicMock()
    mock_cursor = mock.MagicMock()
    mock_conn.cursor.return_value.__enter__ = mock.MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = mock.MagicMock(return_value=False)
    mock_cursor.fetchone.return_value = (42,)
    _conn_mock.return_value = mock_conn

    assert db_module.count_prescriptions() == 42
