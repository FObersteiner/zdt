from pathlib import Path
import pandas as pd

df = pd.read_excel(Path("./directives.ods")).fillna("")
print(df.to_markdown(index=False))

