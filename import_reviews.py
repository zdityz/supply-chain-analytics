import pandas as pd
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

df = pd.read_csv('data/olist_order_reviews_dataset.csv')
df.to_sql('order_reviews', engine, if_exists='replace', index=False)