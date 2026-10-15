import pandas as pd
from flask import Flask, request, jsonify, Response
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from flask_cors import CORS
import requests
import re

app = Flask(__name__)
CORS(app)

# Dataset ကို ဖတ်ခြင်း
try:
    df = pd.read_csv('perfumes_dataset.csv', sep=';', encoding='latin-1', low_memory=False)
except Exception as e:
    print(f"Error loading CSV: {e}")
    df = pd.DataFrame()

if not df.empty:
    df = df.fillna('')
    df['id'] = range(1, len(df) + 1) 

    # AI Recommendation အတွက် Text များ ပေါင်းစပ်ခြင်း
    df['search_text'] = df['Top'].astype(str) + ' ' + df['Middle'].astype(str) + ' ' + df['Base'].astype(str) + ' ' + df['mainaccord1'].astype(str) + ' ' + df['mainaccord2'].astype(str)
    
    # 🌟 Smart Search အတွက် Brand နှင့် Name ကိုပေါင်းပြီး '-' များကို ဖယ်ရှားထားသော Column ဖန်တီးခြင်း
    df['search_name'] = (df['Brand'].astype(str) + ' ' + df['Perfume'].astype(str)).str.replace('-', ' ').str.lower()
    
    vectorizer = TfidfVectorizer(stop_words='english')
    tfidf_matrix = vectorizer.fit_transform(df['search_text'])

# 🌟 Image Proxy Route (CORS လုံခြုံရေးကို ကျော်ဖြတ်ပြီး ပုံအစစ်ပြသရန်)
@app.route('/proxy-image')
def proxy_image():
    img_url = request.args.get('url')
    if not img_url:
        return "No URL provided", 400
    try:
        # Fragrantica ဆာဗာမှ ပိတ်မထားစေရန် Browser အယောင်ဆောင်၍ ပုံကိုလှမ်းဆွဲခြင်း
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
        resp = requests.get(img_url, headers=headers)
        return Response(resp.content, content_type=resp.headers.get('content-type', 'image/jpeg'))
    except Exception as e:
        return str(e), 500

# URL ထဲမှ ID ကိုဆွဲထုတ်၍ ပုံအစစ် Link အဖြစ် ပြောင်းပေးသော Function
def get_real_image(url_string):
    try:
        match = re.search(r'-(\d+)\.html', str(url_string))
        if match:
            perfume_id = match.group(1)
            fragrantica_img = f"https://fimgs.net/mdimg/perfume/375x500.{perfume_id}.jpg"
            # Proxy ကိုဖြတ်၍ ပုံကို ခေါ်ယူခြင်း
            return f"http://192.168.100.136:5000/proxy-image?url={fragrantica_img}"
    except:
        pass
    # Error တက်ပါက ပြသရန် ယာယီပုံ
    return 'https://cdn-icons-png.flaticon.com/512/3050/3050221.png'

# Flutter UI လိုအပ်သော Data Format အတိုင်း ပြင်ဆင်ပေးသည့် Function
def format_results(dataframe):
    results = []
    for _, row in dataframe.iterrows():
        top_notes = [n.strip() for n in str(row['Top']).split(',')] if row['Top'] else ['Unknown']
        mid_notes = [n.strip() for n in str(row['Middle']).split(',')] if row['Middle'] else ['Unknown']
        base_notes = [n.strip() for n in str(row['Base']).split(',')] if row['Base'] else ['Unknown']
        
        perfume_name = str(row['Perfume']).replace('-', ' ').title()
        brand_name = str(row['Brand']).replace('-', ' ').title()

        results.append({
            'id': int(row['id']),
            'name': perfume_name,
            'brand': brand_name,
            'image_url': get_real_image(row['url']), 
            'price_tier': 'Standard',
            'match_score': 95, 
            'longevity': '8 hrs',
            'top_notes': top_notes,
            'middle_notes': mid_notes,
            'base_notes': base_notes
        })
    return results

@app.route('/perfumes', methods=['GET'])
def get_perfumes():
    query = request.args.get('q', '').lower().strip()
    if not query:
        return jsonify({'perfumes': format_results(df.head(20))})
    
    # 🌟 နာမည်ကျော် Brand အတိုကောက်များကို အရှည်သို့ အလိုအလျောက် ပြောင်းပေးခြင်း
    abbreviations = {
        "ysl": "yves saint laurent",
        "jpg": "jean paul gaultier",
        "ck": "calvin klein",
        "ch": "carolina herrera",
        "d&g": "dolce gabbana",
        "dg": "dolce gabbana"
    }
    
    # query ထဲတွင် အတိုကောက်ပါပါက အရှည်ဖြင့် အစားထိုးမည်
    for abbr, full_name in abbreviations.items():
        query = re.sub(rf'\b{abbr}\b', full_name, query)
    
    # စာလုံးတစ်လုံးချင်းစီကို ခွဲ၍ တိကျစွာ ရှာဖွေခြင်း (Smart Search)
    query_words = query.split()
    mask = pd.Series([True] * len(df), index=df.index)
    for word in query_words:
        mask &= df['search_name'].str.contains(word, regex=False)
        
    return jsonify({'perfumes': format_results(df[mask].head(20))})

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.json or {}
    preferred_notes = data.get('preferred_notes', [])
    
    if not preferred_notes:
        return jsonify({'recommendations': format_results(df.head(5))})
        
    user_input = " ".join(preferred_notes)
    user_vec = vectorizer.transform([user_input])
    similarities = cosine_similarity(user_vec, tfidf_matrix).flatten()
    
    top_indices = similarities.argsort()[-5:][::-1]
    return jsonify({'recommendations': format_results(df.iloc[top_indices])})

if __name__ == '__main__':
    if not df.empty:
        print(f"\n✅ အောင်မြင်ပါသည်။ ရေမွှေးပေါင်း {len(df):,} မျိုးကို ချိတ်ဆက်ပြီးပါပြီ!\n")
    app.run(host='0.0.0.0', port=5000, debug=True)