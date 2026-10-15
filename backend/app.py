from flask import Flask, request, jsonify
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

app = Flask(__name__)

# Dataset ကို ဖတ်ခြင်း (Memory သက်သာစေရန် လိုအပ်သော Column များသာ ဖတ်နိုင်သော်လည်း ယခုအတိုင်းထားပါမည်)
df = pd.read_csv('perfumes_dataset.csv', sep=';', encoding='latin-1')

scent_columns = ['Top', 'Middle', 'Base', 'mainaccord1', 'mainaccord2', 'mainaccord3', 'mainaccord4', 'mainaccord5']
for col in scent_columns:
    if col in df.columns:
        df[col] = df[col].fillna('')

available_scent_cols = [col for col in scent_columns if col in df.columns]
df['combined_scents'] = df[available_scent_cols].agg(' '.join, axis=1)

# TF-IDF တွက်ခြင်း (၎င်းသည် Sparse Matrix ဖြစ်၍ Memory အလွန်စားသက်သာသည်)
tfidf = TfidfVectorizer(stop_words='english')
tfidf_matrix = tfidf.fit_transform(df['combined_scents'])

# မှတ်ချက် - Memory မလောက်သောကြောင့် cosine_similarity ကို ဤနေရာတွင် ကြိုမတွက်တော့ပါ။

@app.route('/recommend', methods=['GET', 'POST'])
def recommend():
    if request.method == 'POST':
        data = request.get_json(silent=True)
        perfume_name = data.get('name') if data else None
    else:
        perfume_name = request.args.get('name')
        
    if not perfume_name:
        return jsonify({"error": "Please provide a perfume name."}), 400
        
    idx_list = df.index[df['Perfume'].str.lower() == perfume_name.lower()].tolist()
    
    if not idx_list:
        return jsonify({"error": f"Perfume '{perfume_name}' not found in dataset."}), 404
        
    idx = idx_list[0]
    
    # --- MEMORY အထူးသက်သာစေမည့် ပြင်ဆင်ချက် ---
    # ယခုရှာလိုက်သော ရေမွှေး (၁) မျိုးတည်းကိုသာ ကျန်ရေမွှေးအားလုံးနှင့် ယှဉ်တွက်မည်
    target_vector = tfidf_matrix[idx]
    
    # တွက်ချက်ပြီး ရလာသော ရလဒ်ကို 1D Array အဖြစ် ပြောင်းမည်
    sim_scores_array = cosine_similarity(target_vector, tfidf_matrix).flatten()
    
    sim_scores = list(enumerate(sim_scores_array))
    sim_scores = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    sim_scores = sim_scores[1:6] 
    
    perfume_indices = [i[0] for i in sim_scores]
    
    return_cols = ['Perfume', 'Brand'] + [c for c in ['Top', 'Middle', 'Base'] if c in df.columns]
    recommendations = df.iloc[perfume_indices][return_cols].to_dict(orient='records')
    
    return jsonify({"recommendations": recommendations})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)