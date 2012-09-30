# vim-gdev
Vim上でのGauche開発支援を目的にしたライブラリです。  

### 依存するスクリプト
必須:  
[vimproc](https://github.com/Shougo/vimproc)  
[neocomplcache](https://github.com/Shougo/neocomplcache)  
あった方がいいもの:  
[unite.vim](https://github.com/Shougo/unite.vim)


### 依存する外部プログラム
Gauche 0.9.2以上

## インストール
このライブラリはVimScriptだけでなくGaucheのスクリプトも実行に必要です。  
githubのリポジトリから全てのファイルをダウンロードして、Vimでロード可能な場所に配置してください。  
Vundleがインストールされているのであれば

    Bundle 'aharisu/vim-gdev'
と.vimrcに書いて、Vim上で

    :BundleInstall
を実行すると必要なファイルをすべてインストールすることができます。


## 機能
1. ソースコード内の大域定義とuseしているモジュールの解析を行い 補完候補としてリストアップ
2. Uniteを利用したGaucheシンボル検索
    - 表示する内容
        - シンボルタイプ(変数、関数、クラス...)
        - 定義モジュール(ファイル)名
        - シンボル名
        - 関数であれば引数、クラスであればスロット名
        - それぞれに付随するドキュメント
    - 表示内容の例(lambdaを選択した場合)

            Function  ---null
            (lambda formals body ...)

            --description--
            [R5RS+]
            この式は評価されると手続きを生成します。この式が評価された時点の環境が手続き中に保持されます。
            手続きが呼ばれると、記憶された環境に引数の束縛を追加した環境中でbody が順に評価され、
            最後の式の値が返されます。
            ...
    - Uniteソース一覧
        - gosh_info
            + 現在のファイル内で参照可能なシンボルの一覧を表示します。
        - gosh\_all\_symbol
            + インストールされている全てのモジュールがexportしている全てのシンボル一覧。
        - gosh\_all\_module
            + インストールされている全てのモジュール一覧。  
            続けて、選択したモジュール内のシンボル一覧。
3. 定義へジャンプ
    - シンボルが定義されたファイルを開きその行へジャンプします。  
    schemeレベルで定義されているシンボルであればGaucheライブラリ内で定義されたシンボルにもジャンプすることができます。  
    ただし、ジャンプ前の地点を保存していないので元の場所には戻れません。  
    Basic setupで設定しているように適当なキーにマッピングして使用してください。


## Basic setup
    ":Unite gosh_infoを実行します
    nmap gi <Plug>(gosh_info_start_search)
    ":Unite カーソル位置のシンボルを初期値に:Unite gosh_infoを実行します
    nmap gk <Plug>(gosh_info_start_search_with_cur_keyword)
    imap <C-A> <Plug>(gosh_info_start_search_with_cur_keyword)

    "ginfoウィンドウのスクロールアップ・ダウン
    nmap <C-K> <Plug>(gosh_info_row_up)
    nmap <C-J> <Plug>(gosh_info_row_down)
    imap <C-K> <Plug>(gosh_info_row_up)
    imap <C-J> <Plug>(gosh_info_row_down)
    "ginfoウィンドウを閉じます
    nmap <C-C> <Plug>(gosh_info_close)
    imap <C-C> <Plug>(gosh_info_close)

    "カーソル位置のシンボルが定義されている場所にジャンプ
    nmap <F12> <Plug>(gosh_goto_define)
    nmap <F11> <Plug>(gosh_goto_define_split)
