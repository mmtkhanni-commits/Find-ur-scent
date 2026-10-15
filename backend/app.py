from flask import Flask, request, jsonify
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

app = Flask(__name__)

# Dataset ကို ; ဖြင့် ခွဲ၍ ဖတ်ခြင်း (ဖိုင်နာမည် perfumes_dataset.csv အမှန်ဖြစ်ရမည်)
df = pd.read_csv('perfumes_dataset.csv', sep=';',encoding='latin-1')

# အနံ့ဆိုင်ရာ Column များကို ပေါင်းစပ်ရန် ပြင်ဆင်ခြင်း (NaN များကို စာသားအလွတ်ဖြင့် အစားထိုးခြင်း)
scent_columns = ['Top', 'Middle', 'Base', 'mainaccord1', 'mainaccord2', 'mainaccord3', 'mainaccord4', 'mainaccord5']
for col in scent_columns:
    if col in df.columns:
        df[col] = df[col].fillna('')

# အနံ့အားလုံးကို စာကြောင်းတစ်ကြောင်းတည်းဖြစ်အောင် ပေါင်းခြင်း
available_scent_cols = [col for col in scent_columns if col in df.columns]
df['combined_scents'] = df[available_scent_cols].agg(' '.join, axis=1)

# TF-IDF နှင့် Cosine Similarity ကို တွက်ချက်ခြင်း (App စတင်ကတည်းက တစ်ခါတည်း တွက်ထားမည်)
tfidf = TfidfVectorizer(stop_words='english')
tfidf_matrix = tfidf.fit_transform(df['combined_scents'])
cosine_sim = cosine_similarity(tfidf_matrix, tfidf_matrix)

@app.route('/recommend', methods=['GET', 'POST'])
def recommend():
    # Browser (GET) နှင့် Flutter (POST) နှစ်မျိုးစလုံးကို လက်ခံရန်
    if request.method == 'POST':
        # Flutter မှ JSON Data ပို့သောအခါ
        data = request.get_json(silent=True)
        perfume_name = data.get('name') if data else None
    else:
        # Browser မှ ?name=... ဖြင့် ခေါ်သောအခါ
        perfume_name = request.args.get('name')
        
    if not perfume_name:
        return jsonify({"error": "Please provide a perfume name."}), 400
        
    # ရေမွှေးနာမည်ကို Dataset ထဲတွင် ရှာခြင်း (အကြီး/အသေး ဂရုမစိုက်ဘဲ ရှာမည်)
    idx_list = df.index[df['Perfume'].str.lower() == perfume_name.lower()].tolist()
    
    if not idx_list:
        return jsonify({"error": f"Perfume '{perfume_name}' not found in dataset."}), 404
        
    idx = idx_list[0]
    
    # ယခုရေမွှေးနှင့် အခြားရေမွှေးများ၏ တူညီမှုရာခိုင်နှုန်းများကို ယူခြင်း
    sim_scores = list(enumerate(cosine_sim[idx]))
    
    # အများဆုံးတူညီသော ရေမွှေးများကို အစဉ်လိုက်စီခြင်း
    sim_scores = sorted(sim_scores, key=lambda x: x[1], reverse=True)
    
    # နံပါတ် 1 မှ 5 အထိ (အနံ့အဆင်တူဆုံး ၅ မျိုး) ကို ယူခြင်း (၀ က မိမိကိုယ်တိုင်ဖြစ်နေ၍ ချန်လှပ်ထားသည်)
    sim_scores = sim_scores[1:6] 
    
    perfume_indices = [i[0] for i in sim_scores]
    
    # ရလဒ်များကို JSON အဖြစ် ပြန်ပို့ပေးခြင်း
    return_cols = ['Perfume', 'Brand'] + [c for c in ['Top', 'Middle', 'Base'] if c in df.columns]
    recommendations = df.iloc[perfume_indices][return_cols].to_dict(orient='records')
    
    return jsonify({"recommendations": recommendations})

if __name__ == '__main__':
    # 0.0.0.0 ကိုသုံးထားသဖြင့် Local Network အတွင်းရှိ ဖုန်းများမှပါ ဝင်ရောက်စမ်းသပ်နိုင်မည်
    app.run(host='0.0.0.0', port=5000, debug=True)