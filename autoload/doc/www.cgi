
;;;;;
;;@type cmd
;;@@parse-relative #f


;;;;;
;;@type Parameter
;;@name cgi-temporary-files
;;@description cgi-add-temporary-fileで登録された一時ファイルを保持するパラメータです。
;;

;;;;;
;;@type Function
;;@name cgi-add-temporary-file
;;@description この手続きはcgi-mainに渡されるproc中で呼ばれることを
;;想定しています。
;;この手続きは、filenameを一時ファイルとして登録し、procが
;;終了する際に消去されるようにします。cgiスクリプトがエラー終了した場合
;;などでもごみを残さないようにする便利な方法です。
;;この手続きを呼んだ後で、procがfilenameを消去したり
;;名前を変えたりしても構いません。
;;
;;@param filename 

;;;;;
;;@type Function
;;@name cgi-main
;;@description CGIスクリプトのための便利なラッパー手続きです。
;;この手続きは、まずcgi-parse-parametersを呼び出してCGIスクリプトに
;;渡されたパラメータを解析し、続いてその結果を引数としてprocを呼び出します。
;;キーワード引数merge-cookiesは、与えられればそのまま
;;cgi-parse-parametersに渡されます。
;;
;;手続きprocはHTTPヘッダを含むドキュメントを
;;テキストツリー構造(Lazy text construction参照)で
;;返さなければなりません。cgi-mainはそれをwrite-treeを使って
;;現在の出力ポートに書き出し、0を返します。
;;
;;もしproc内でエラーが起こった場合、そのエラーは捕捉されて、エラーを報告する
;;HTMLページが作成されて出力されます。このエラーページは、on-errorキーワード引数に
;;手続きを渡すことでカスタマイズできます。on-errorに渡された手続きは
;;エラー発生時に<condition>オブジェクト(Conditions参照)
;;を引数として呼ばれ、HTTPヘッダを含むドキュメントをテキストツリー構造で返さねばなりません。
;;
;;cgi-mainは最終的な結果を出力を書き出す時に
;;パラメータcgi-output-character-encodingを参照し、
;;必要ならば出力の文字エンコーディングを変換します。
;;
;;cgi-mainの出力のふるまいはキーワード引数output-procで
;;カスタマイズできます。output-procが渡された場合、それは
;;procの戻り値、あるいはエラーハンドラが作成したテキストツリー構造を
;;受け取る手続きでなければなりません。その手続きはテキストツリーを
;;フォーマットして現在の出力ポートに出力しなければなりません。
;;必要ならば文字エンコーディングの変換もその手続き内で行います。
;;
;;キーワード引数part-handlersは、そのままcgi-parse-parameters
;;に渡されます。この引数によって、ファイルアップロードの際の動作をカスタマイズ
;;できます。詳しくは下の「ファイルアップロードの処理」の項を参照して下さい。
;;
;;この引数で、一時ファイルを使うように指定した場合、cgi-mainは
;;procから抜ける際に(エラーでも正常終了でも)一時ファイルを
;;消去します。この機能を他でも利用するにはcgi-add-temporary-fileの項を
;;参考にして下さい。
;;
;;procを呼ぶ前に、cgi-mainはカレントエラーポートの
;;バッファリングモードを:lineに変更します。
;;(バッファリングモードの詳細についてはCommon port operationsの
;;port-bufferingの項を参照してください)。
;;これはwebサーバがcgiスクリプトのエラー出力を捕捉しやすくするためです。
;;
;;以下の例はCGIに渡されたパラメータ全てをテーブルにして表示します。
;;
;;example:
;;  #!/usr/local/bin/gosh
;;  
;;  (use text.html-lite)
;;  (use www.cgi)
;;  
;;  (define (main args)
;;    (cgi-main
;;      (lambda (params)
;;        `(,(cgi-header)
;;          ,(html-doctype)
;;          ,(html:html
;;            (html:head (html:title "Example"))
;;            (html:body
;;             (html:table
;;              :border 1
;;              (html:tr (html:th "Name") (html:th "Value"))
;;              (map (lambda (p)
;;                     (html:tr
;;                      (html:td (html-escape-string (car p)))
;;                      (html:td (html-escape-string (x->string (cdr p))))))
;;                   params))))
;;         ))))
;;
;;@param proc 
;;@param :key 
;;@param on-error 
;;@param merge-cookies 
;;@param output-proc 
;;@param part-handlers 

;;;;;
;;@type Parameter
;;@name cgi-output-character-encoding
;;@description このパラメータの値は次に説明するcgi-mainが出力するデータの
;;文字符合化法(CES)を指定します。デフォルトの値はGaucheのネイティブエンコーディング
;;です。それ以外の値がセットされている場合、cgi-mainは
;;gauche.charconvモジュールを用いて出力のエンコーディングの変換を
;;行います。
;;(Character code conversion参照)。
;;
;;@param :optional 
;;@param encoding 

;;;;;
;;@type Function
;;@name cgi-header
;;@description HTTPリプライメッセージのヘッダを、テキストツリー形式(Lazy text construction参照)
;;で作成して返します。最も簡単な呼び出しでは次のようになります。
;;example:
;;  (tree->string (cgi-header))
;;    ==> "Content-type: text/html\r\n\r\n"
;;
;;キーワード引数content-typeによってContent typeを指定できます。
;;また、cookiesにクッキー文字列のリストを渡すことにより、
;;クライアントにクッキーを設定できます。クッキー文字列を構築するには手続き
;;construct-cookie-string (HTTP cookie handling参照)
;;が使えます。
;;
;;キーワード引数locationは、Locationヘッダを作成して
;;クライアントを別のURIに誘導するのに使えます。また、Statusヘッダを
;;指定するためにstatusキーワード引数が使えます。クライアントを
;;別URIに転送するよくある方法は次のようなものです。
;;
;;example:
;;  (cgi-header :status "302 Moved Temporarily"
;;              :location target-uri)
;;
;;
;;@param :key 
;;@param status 
;;@param content-type 
;;@param location 
;;@param cookies 

;;;;;
;;@type Function
;;@name cgi-get-parameter
;;@description cgi-parse-parametersが返す、パーズされたQuery文字列paramsから、
;;名前nameを持つパラメータの値を簡単に取り出すための手続きです。
;;nameは文字列です。
;;
;;キーワード引数listに真の値が与えられていなければ、
;;返される値はスカラー値です。パラメータnameに複数の値が与えられた場合でも、
;;最初の値のみが返されます。listに真の値が与えられれば、返されるのは
;;常に値のリストとなります。
;;
;;キーワード引数convertに手続きを与えると、対応する値が取り出された後でその
;;手続きが値を引数として呼ばれます。これによって値を文字列から必要な型へと変換することが
;;できます。listに真の値が与えられている場合、変換手続きは各値に対して呼ばれ、
;;その結果のリストがcgi-get-parameterから返されます。
;;
;;パラメータnameがQuery中に現れなかった場合は、
;;defaultに与えられた値がそのまま
;;返されます。defaultが省略された場合、listが偽であれば#fが、
;;真であれば()が返されます。
;;
;;@param name 
;;@param params 
;;@param :key 
;;@param :default 
;;@param :list 
;;@param :convert 

;;;;;
;;@type Function
;;@name cgi-parse-parameters
;;@description CGIプログラムに渡されたquery stringをパーズして、パラメータの連想リストにして
;;返します。文字列がキーワード引数query-stringに与えられればそれがパーズすべき
;;query stringとなります。その引数が渡されなければこの手続きは
;;メタ変数REQUEST_METHODを参照し、その値によって標準入力もしくは
;;メタ変数QUERY_STRINGからquery stringが取られます。
;;そのようなメタ変数が定義されておらず、かつ現在の入力ポートが端末である場合、
;;インタラクティブにデバッグをしているものと考えて、
;;この手続きはプロンプトを出してユーザにパラメータの入力を促します。
;;
;;REQUEST_METHODがPOSTの場合、この手続きはenctypeとして
;;application/x-www-from-urlencodedとmultipart/form-dataの
;;両方を処理できます。後者は通常、ファイルアップロード機能を持つフォームに使われます。
;;
;;POSTデータがmultipart/form-dataで送られて来た場合、
;;各パートの内容がパラメータの値となります。すなわち、アップロードされた
;;ファイルはその内容がひとつの文字列として得られることになります。
;;元のファイル名のようなその他の情報は捨てられます。これが望ましい動作で
;;ない場合は、part-handlers引数によって動作をカスタマイズすることができます。
;;詳しくは下の「ファイルアップロードの処理」で説明します。
;;
;;キーワード引数merge-cookiesに真の値が与えられた場合は、
;;メタ変数HTTP_COOKIEからクッキーの値が読まれ、解析されて
;;結果に追加されます。
;;
;;パラメータは複数の値を取り得るため、結果のパラメータに対応する値は常にリストになります。
;;パラメータに値が与えられていなければ、結果のパラメータに対する値には#tが置かれます。
;;次の例を参照して下さい。
;;example:
;;  (cgi-parse-parameters
;;    :query-string "foo=123&bar=%22%3f%3f%22&bar=zz&buzz")
;;   ==> (("foo" "123") ("bar "\"??\"" "zz") ("buzz" #t))
;;
;;@param :key 
;;@param :query-string 
;;@param :merge-cookies 
;;@param :part-handlers 

;;;;;
;;@type Function
;;@name cgi-get-metavariable
;;@description nameで指定されるCGIメタ変数の値を返します。
;;この関数はまずパラメータcgi-metavariablesを探し、
;;指定されたメタ変数が見つからなければsys-getenvを呼びます。
;;
;;CGIスクリプトは、なるべくsys-getenvを直接呼ぶのではなく
;;cgi-get-metavariableを使うのが良いでしょう。
;;スクリプトの再利用もしやすくなります。
;;
;;@param name 

;;;;;
;;@type Parameter
;;@name cgi-metavariables
;;@description 通常、httpdはcgiプログラムに様々な情報を環境変数経由で渡します。
;;www.cgi中の多くの手続きはその情報(メタ変数)を参照します。
;;しかし、cgiに関連するプログラムを開発中に環境変数にアクセスするのは
;;不便な場合もあります。
;;このパラメータを使うと、メタ変数をオーバライドすることができます。
;;
;;Metavariablesは2要素のリストのリストです。
;;内側のリストは、最初の要素が変数名を、2つめの要素がその値を、それぞれ
;;文字列で与えます。
;;
;;例えば次のコードはREQUEST_METHODと
;;QUERY_STRINGのメタ変数をmy-cgi-procedureの実行期間中に
;;上書きします。(parameterizeの詳細については
;;Parametersを参照して下さい)。
;;
;;example:
;;  (parameterize ((cgi-metavariables '(("REQUEST_METHOD" "GET")
;;                                      ("QUERY_STRING" "x=foo"))))
;;    (my-cgi-procedure))
;;
;;@param :optional 
;;@param metavariables 

