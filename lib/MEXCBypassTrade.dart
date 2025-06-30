import 'dart:convert';
import 'package:http/http.dart' as http;

void makeRequest() async {
  var url = Uri.parse('https://www.mexc.com/ucgateway/captcha_api/captcha/robot/robot.future.openlong.BTC_USDT.400X');

  var headers = {
    'accept': '*/*',
    'accept-encoding': 'gzip, deflate, br, zstd',
    'accept-language': 'en-GB,en-US;q=0.9,en;q=0.8',
    'captcha-token': 'geetest eyJsb3ROdW1iZXIiOiIxN2FjNjFhNDAxY2M0MWE4YmMwNWM4YWU2NmQ4MGM2MSIsImNhcHRjaGFPdXRwdXQiOiJaVkwzS3FWaWxnbEZjQWdXOENIQVgtWXhxUUpMSEFXS0RzamZNZ21Ldjl3MGFnR3Rjb09wU3VSSVRSejBpWGkwc3lmQ1BqenQtcmpNQ1NBSHFaR1RGeU9TelgwSnpDTmZzaFhGNm1kbG80eDY5RkFOaE9BcEc4ZFFxTHlJM2Z2LVdKNWZQUklQREZ5ekhoQnNfMUdkZGV1RGJfOVBSRDcxRFdwTFBrbHJPcVA2Nko0WmtoSkNLamtnTE9iV21jcjNTa0FRYXZWNjRaQ2RLTmxwbV9ya2djQXFnYXJ0YUdjbTU0U25UbFZGejJyekdwRmFjRER4TFZlZWtSTl92TWNfYWpEVXM4SmF0Nk52ZVNQQ3NmbVhGTVAwUWZudk5IcU84cUVwQ1VvUUNrcHBqcFJEVlhSOW1jZXUzMUI2c3daN3BFalhRb2pkV3M0eTdWWkdhemV1N1Z3bDZGZ2JyaWV0NEJjMDE5TUZyeFVvNVJKZFpydWx0a21peFFKTHI3eDdvSktzTG96WlpEeWJFRDFjWTRYTndpSGR1eXJxSEtYbVEtS0VtaW9MbHBTRjZ0M2tFSnFLTXJBaDRGT2Nfcnp4ODNBWEZCY3Zsb3BjWjRwN2hsVzhud19ydHF1bUYtVWp2Z0l2U1lPazVlcHg0bVhueHJnUmdoeXR0QnZlVzN2eG85TlJUZUl3QmN0M29uTFNhcUJrQjBqQzV5ZVZzTlQ0RlJtemF3U1VCUWc9IiwicGFzc1Rva2VuIjoiZThjOWU4YzY2YTA0OTI1ZjViOWFmNWZhMmM3N2JkNzY4MGI4M2NlZDAzY2RkZjI1ODg3YjUyNmZlNGU3MzlhZCIsImdlblRpbWUiOiIxNzM5ODgyMzA0In0=',
    'content-type': 'application/json',
    'cookie': '_ga=GA1.1.764923448.1735709526; _fbp=fb.1.1735709540528.575787965215436984; g_state={"i_l":0}; _ym_uid=173964056915906760; _ym_d=1739640569; mxc_theme_main=dark; NEXT_LOCALE=en-US; mxc_exchange_layout=BA; uc_token=WEB6d8f58d489f302a816f838bd9ad19af8fdca27538a959f1685728e9d9e13be0e; x-mxc-fingerprint=5ef211f23a22e8dfcbc525fb6aceb0a4; u_id=WEB6d8f58d489f302a816f838bd9ad19af8fdca27538a959f1685728e9d9e13be0e; CLIENT_LANG=en-US; mxc_theme_upcolor=upgreen; _vid_t=a4zEJ1lHpS+zmsgYunYqryz41yN4TK47LOvpk78FK0Hr4DJ0R3zByq13gw5HPPiddSrS6kld8x/ewZsxqVxQ6OtBD9SL7QaQSGBs9ls=; mexc_fingerprint_visitorId=4ZFHDftpsj7rl3GcUslw; mexc_fingerprint_requestId=1739641573308.PTWDc7; _abck=13F1DAFF31980153D45CF7541E9ECE02~0~YAAQkI4QAnt9dASVAQAAir3eGA3eEe1OuAluddbRWMVVKVbr0uCxrFixGybhVz/06aX35qu3Vig3OSG1r46BZkkgcmmHPQ7D4BpvKEcshFkTgRoxpXi1/3lX0sPw5hJSYJVneIgyUESUGRIueDITS0qxLKEy7IZyZ+gPfDIheyN1bJcJkY1679oVLP4bxcLom+CWc7k05qQYUaJKEfyuPJouPfXwj5GJzhAFPrdxc8Ek2s8zRctZy0XqkO3FwEiz76GI/3aEofjN3j8ZeSRsYadGFJUhCQ4P1fjoCeKUiaUB9SCRm4GgXyPO/1opVOUWOWqBhH6BZLMcAcrQX8gv648nyHh+6zesVA+wzrTSZTu60Xwlic960orjfjDypZLnwPzI8pVkB4npZUmcWVuxly/cejTHfa5KaYQkGmrdMMFigrDZT6gdJjXmUVbgfKz90nApArbTZeqoRIVcmJBOUHOnZ8sRFIr0lzYUeA6o3ms3SQI/ZBqACnNgk19cgWJQomUts8ydbhduBPVHACt85bdNzxMCcmlJf7EtoPCzLSQPXWYD4gsd99GfdOXvz30Kq47Z8graNzeUE281pZaEQlEubihySzM9lWVfdq6brIG/DGhfQK35PRAZE6HOkLUUbHkeyn4DqFjoIZWR+2+tYfXzELfYgZYw0PD+mFv2c7M92CMb17Glt1OJCvxmxAaeEYCy9bm/TgYd~-1~-1~-1',
    'language': 'en',
    'origin': 'https://futures.mexc.com',
    'referer': 'https://futures.mexc.com/',
    'sec-ch-ua': '"Not A(Brand";v="8", "Chromium";v="132", "Google Chrome";v="132"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'user-agent': 'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36'
  };

  var response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    print('Response body: ${response.body} ${response.statusCode}');
  } else {
    print('Request failed with status: ${response.statusCode}');
  }
}

void main() {
  makeRequest();
}
