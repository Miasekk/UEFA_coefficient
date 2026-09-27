from pathlib import Path
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.types import Boolean, Date, DateTime, Integer, String, Text

# 1. Połączenie z bazą PostgreSQL w kontenerze Dockera
DB_URL = "postgresql://postgres:postgres@127.0.0.1:5433/uefa"
engine = create_engine(DB_URL)

# 2. Dynamiczne wyznaczenie ścieżki do folderu z plikami CSV
BASE_DIR = Path(__file__).resolve().parent.parent
PROCESSED_DIR = BASE_DIR / "data" / "processed"

# 3. Jawna definicja typów kolumn w PostgreSQL (nazwy po standaryzacji: lower + snake_case)
POSTGRES_DTYPES = {
    "competition": String(50),
    "season": String(20),
    "season_start_year": Integer(),
    "round": String(100),
    "matchweek": Integer(),
    "day": String(20),
    "date": Date(),
    "time": String(10),
    "host_country": String(100),
    "host": String(100),
    "host_goals": Integer(),
    "score": String(20),
    "guest_country": String(100),
    "guest": String(100),
    "guest_goals": Integer(),
    "attendance": Integer(),
    "venue": String(150),
    "referee": String(100),
    "notes": String(255),
    "competition_phase": String(50),
    "extra_time": Boolean(),
    "penalty_kicks": Boolean(),
    "penalty_kicks_result": String(20),
    "host_penalties_scored": Integer(),
    "guest_penalties_scored": Integer(),
}


def init_database():
    """Tworzy schematy analityczne: staging (warstwa przygotowawcza) oraz marts (warstwa modeli docelowych)."""
    with engine.connect() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS marts;"))
        conn.commit()
    print("✓ Schematy 'staging' oraz 'marts' zostały zainicjalizowane.")


def load_staging_data():
    """Wyszukuje i wczytuje pliki CSV do schematu staging."""
    # 1. Sprawdzenie, czy folder fizycznie istnieje
    if not PROCESSED_DIR.exists():
        print(f"Błąd: Folder {PROCESSED_DIR} nie istnieje!")
        return

    # 2. Wyszukanie wszystkich plików .csv
    csv_files = list(PROCESSED_DIR.glob("*.csv"))
    if not csv_files:
        print(f"Błąd: Nie znaleziono żadnych plików .csv w folderze {PROCESSED_DIR}!")
        return

    print(f"\n--- Znaleziono {len(csv_files)} plików CSV. Rozpoczynam ładowanie do schematu 'staging' ---")

    for file_path in csv_files:
            table_name = file_path.stem.lower().replace(" ", "_").replace("-", "_")
            print(f"-> Ładowanie {file_path.name} do tabeli staging.{table_name}...")

            # Wczytanie pliku
            df = pd.read_csv(file_path)

            # Standaryzacja nazw kolumn pod SQL
            df.columns = [
                col.strip().lower().replace(" ", "_").replace("-", "_")
                for col in df.columns
            ]

            # Konwersja kolumny date na format datetime przed zapisem
            if "date" in df.columns:
                df["date"] = pd.to_datetime(df["date"], errors="coerce").dt.date

            # Wybór typów tylko dla kolumn obecnych w tym konkretnym pliku
            current_dtypes = {
                col: POSTGRES_DTYPES[col]
                for col in df.columns
                if col in POSTGRES_DTYPES
            }

            # Eksport do tabeli w Postgresie
            df.to_sql(
                name=table_name,
                con=engine,
                schema="staging",
                if_exists="replace",
                index=False,
                dtype=current_dtypes,
            )
            print(f"   ✓ Zapisano {len(df)} wierszy.")


if __name__ == "__main__":
    print(">>> ROZPOCZYNAM WYKONYWANIE PROGRAMU <<<")
    init_database()
    load_staging_data()
    print("\n🎉 Sukces! Wszystkie tabele znajdują się w schemacie 'staging' w PostgreSQL!")