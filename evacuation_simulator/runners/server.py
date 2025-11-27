from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import io
import sys
import os
from contextlib import redirect_stdout

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

from run_agent_path_demo import run_demo_full

app = FastAPI()

class SimulationRequest(BaseModel):
    scenario_name: str
    agent_index: int = 800 

@app.post("/simulate")
async def run_simulation(req: SimulationRequest):
    """
    Flutter 앱에서 호출하는 API.
    """
    try:
        f = io.StringIO()
        
        with redirect_stdout(f):
            run_demo_full(
                scenario_name=req.scenario_name,
                agent_index=req.agent_index,
                verbose=True 
            )
        output_text = f.getvalue()
        return {"result": output_text}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)