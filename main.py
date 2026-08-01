from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy import create_engine
import pandas as pd
import os
from dotenv import load_dotenv
import joblib

load_dotenv()

app = FastAPI(title="Olist E-commerce Analytics API")

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

model = joblib.load('churn_model.joblib')

class CustomerData(BaseModel):
    recency: float
    frequency: int
    monetary: float
    avg_review_score: float
    delivery_delay_days: float
    freight_ratio: float

@app.get("/")
def health_check():
    return {"status": "Operational", "service": "Olist Analytics ML Backend"}

@app.get("/api/v1/segments/rfm")
def get_rfm_segments():
    query = """
    SELECT customer_segment, COUNT(customer_id) as segment_count
    FROM rfm_scores
    GROUP BY customer_segment
    ORDER BY segment_count DESC;
    """
    with engine.connect() as connection:
        df = pd.read_sql(query, connection)
    return df.to_dict(orient="records")

@app.post("/api/v1/predict/churn")
def predict_churn(customer: CustomerData):
    data = pd.DataFrame([customer.model_dump()])
    
    prediction = model.predict(data)[0]
    probability = model.predict_proba(data)[0][1]
    
    return {
        "churn_prediction": int(prediction),
        "churn_probability": round(float(probability), 4)
    }