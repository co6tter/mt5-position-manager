# 実装計画

この変更では、パネルを6つの機能タブへ分割して小型化し、折り畳みと成り行きエントリーを追加する。同時に、ポジション行とStatusの長文が表示領域で切れる問題を解消し、価格・Ticket・retcodeを最後まで確認できるようにする。

## 目的

通常時のパネル占有面積を減らしながら、既存のポジション管理、自動決済、保護機能へ素早くアクセスできるUIへ再編する。チャート銘柄への成り行きBuy/Sellを、パネルで指定したロットと初期SL/TPを使って確認ダイアログなしで実行できるようにする。

ポジション表示とStatusは、利用者の判断に必要な値を省略しない。USDJPYのTPが`159.520`の場合は末尾の0まで表示し、長い失敗メッセージもパネル上で全文を読めることを必須とする。

## 現状

- `src/UiPanel.mqh`は、Positions、SL/TP、Auto Close、Equity Guard、Break Even、Trailingを1枚のパネルへ常時配置している。最小幅は`780px`で、表示中の機能だけを小さく見せる仕組みはない。
- タイトルバーのドラッグ移動と右下からのリサイズは実装済みだが、折り畳み状態はない。
- `src/TradeManager.mqh`は`PositionClose()`と`PositionModify()`を扱うが、`CTrade::Buy()`と`CTrade::Sell()`による新規エントリーには対応していない。
- `src/Constants.mqh`の`PMFormatPrice()`は`SYMBOL_DIGITS`を使って`DoubleToString()`を呼ぶ。そのため、USDJPYの`159.520`が`159.5`までしか見えない現象は価格丸めではなく、`src/UiPanel.mqh`がポジション情報を1本の長いボタン文字列として描画し、表示幅を超えた部分が切れている可能性が高い。
- Statusも単一の`OBJ_LABEL`へ全文を設定しており、折り返しや複数行表示がない。パネル幅を超えるメッセージは途中で見えなくなる。
- `docs/specification.md`と`README.md`では、新規Buy/Sellを対象外としている。
- Cross-project knowledge baseには、このMT5 UIと表示欠けへ直接適用できる記録はなかった。現行リポジトリとMQL5公式仕様を設計根拠とする。

## スコープ

### 対象

- `Entry`、`Positions`、`SL-TP`、`Auto`、`Guard`、`Trail`の6タブ
- タイトルバーだけを残すパネルの折り畳み
- 折り畳み状態でのドラッグ移動
- チャート銘柄に対する成り行きBuy/Sell
- ロットと初期SL/TPのパネル入力
- 現在価格を基準にしたSL/TP値のクリック増減と価格プレビュー
- ポジション行の構造化と、`SYMBOL_DIGITS`に従った価格の完全表示
- Statusの自動折り返しと動的な複数行表示
- Pure Tests、手動テスト、仕様書、READMEの更新

### 対象外

- Pending Order、指値・逆指値エントリー
- Risk %による自動ロット計算
- Magic Numberによるポジション所有権の判定やフィルタ
- エントリー戦略やシグナル生成
- Buy/Sell前の確認ダイアログ
- パネル設定や入力値の永続化

## 前提

- エントリー対象は、EAを配置しているチャートの`_Symbol`とする。
- Buy/Sellボタンは1クリックにつき同期的な注文要求を1回送る。複数回のクリックは、それぞれ独立した注文意図として扱う。
- エントリーのSL/TPは現在価格からのpoints距離として保持する。`0`は未設定、正数は有効な距離とする。
- Entryタブは最新Bid/Askと、Buy/Sellそれぞれの計算済みSL/TP価格を表示する。Timer更新で距離入力を上書きせず、価格プレビューだけを再計算する。
- ロットの`- / +`は`SYMBOL_VOLUME_STEP`、SL/TP距離の`- / +`は1 point単位とする。ロットは`SYMBOL_VOLUME_MIN`から開始し、`SYMBOL_VOLUME_MAX`を超えない。
- ポジション価格は`SYMBOL_DIGITS`に従う。表示幅を確保するために小数桁を削減してはならない。
- タブを非表示にしても、Auto Close、Equity Guard、Break Even、TrailingのTimer評価は継続する。

## 未解決の疑問・矛盾

なし。

## 受け入れ条件

### タブとパネル

- 展開状態では`Entry`、`Positions`、`SL-TP`、`Auto`、`Guard`、`Trail`の6タブが表示され、選択したタブの本文だけが表示される。
- 非選択タブのオブジェクトは表示されず、クリックしてもイベントを発生させない。
- 展開時の標準幅は現在の`780px`より小さく、目標`560px`以下とする。すべてのタブで背景外へのはみ出しや操作部品の重なりがない。
- 折り畳むとタイトルと展開ボタンだけが残り、タブ本文、Status、リサイズグリップは表示されない。
- 折り畳み中も、展開ボタン以外のタイトルバー領域をドラッグするとパネルが移動する。
- 再展開すると、折り畳み前の位置、幅、選択タブ、入力値、選択Ticketが復元される。
- Positions以外のタブを表示している間も、ポジション情報と既存の自動機能の内部状態は更新される。

### 成り行きエントリー

- Entryタブに`_Symbol`、最新Bid/Ask、Lot、SL points、TP points、方向別SL/TPプレビュー、Buy/Sellボタンが表示される。
- Lotの`- / +`は銘柄のVolume Step単位で変化し、Volume Min未満またはVolume Max超にはならない。
- SL/TPの`- / +`は1 point単位で変化し、負数にはならない。
- Buyは実行時点のAsk、Sellは実行時点のBidを使う成り行き注文を1回だけ送る。`CTrade::Buy()`と`CTrade::Sell()`には実行価格`0.0`を渡し、端末の最新価格を使用する。
- SL/TPが`0`なら該当する保護価格を`0.0`で送る。正数なら、最新価格から絶対価格を算出し、Tick Sizeへ正規化したうえでStops LevelとFreeze Levelを検証する。
- 有効な要求が約定または受付された場合、side、symbol、volume、result price、deal、orderをStatusとExpertsログへ記録する。
- 無効なロット、取得できないTick、不正なSL/TPでは注文要求を送らず、理由をStatusへ表示する。
- 失敗時はretcodeとdescriptionを表示する。timeout、connection、結果不明の要求を自動再試行しない。
- Buy/Sell押下時に確認ダイアログを表示しない。

### ポジション表示

- Positionsタブは、各表示行でSymbol、Side、Lot、Entry、SL、TP、Profit、Ticketを確認できる。
- 価格表示は銘柄の`SYMBOL_DIGITS`と一致する。USDJPYのTPが`159.520`の場合、画面上にも`TP=159.520`と表示される。
- Position行の末尾まで表示できない場合、小数桁やTicketを削るのではなく、固定列または複数行のコンパクト表示へ切り替える。
- パネルを最小幅にしても、Entry、SL、TP、Profit、Ticketのいずれも横方向のクリッピングで欠落しない。
- 行のどの選択領域をクリックしても、従来どおりTicket単位で選択・選択解除できる。
- ページング、Select All、Clear Selection、Close Selectedの挙動は維持される。

### Status表示

- Statusはパネル本文幅に合わせて単語境界または文字数で折り返され、必要な行数だけStatus領域が高くなる。
- `SL clear stopped: trading unavailable (auto trading disabled by client)`が末尾までパネル内に表示される。
- `ticket`、`retcode`、`description`を含む失敗メッセージが途中で省略されない。
- 短いStatusは1行のままとし、通常時のパネル高を不必要に増やさない。
- Statusの高さが変化したとき、背景、リサイズグリップ、チャート端への位置制約も再計算される。
- 折り畳み中にStatusが更新された場合、再展開時に最新メッセージの全文が表示される。

### 互換性と品質

- Close NowとClose Selectedの確認ダイアログは維持される。
- 既存のSL/TP変更、Clear SL/TP、Auto Close、Equity Guard、Break Even、Trailingがタブ分割後も同じ設定値と処理条件で動く。
- 既存Pure Testsと追加Pure Testsがすべて`[PASS]`になる。
- EAとPure Testsのコンパイルログに`0 errors`が含まれる。

## 影響範囲

### 直接の変更

- `src/Models.mqh`: タブ種別、成り行き注文の入力・結果モデル
- `src/Constants.mqh`: コンパクトパネル、タブ、折り畳み、Position行、Status行の寸法定数と表示用の純粋ヘルパー
- `src/ValidationService.mqh`: ロット正規化、エントリーSL/TP価格計算、Broker制約の検証
- `src/TradeManager.mqh`: 成り行きBuy/Sell、結果判定、ログ出力
- `src/UiPanel.mqh`: タブ、折り畳み、Entry UI、Position固定列または複数行表示、Status折り返し、動的レイアウト

### 間接的な影響

- `src/PositionManager.mq5`: Timer描画とチャートイベントから追加UI状態・注文処理への接続
- 既存のパネル移動、リサイズ、ページング、選択状態、Timer処理
- netting口座では反対方向の成り行き注文が既存ポジションを相殺または反転させる可能性がある。hedging口座では別Ticketとして追加される。

### テストとドキュメント

- `tests/PositionManagerPureTests.mq5`: volume正規化、SL/TP計算、表示文字列、Status折り返し
- `tests/manual-test-plan.md`: タブ、折り畳み、ドラッグ、表示欠け、Buy/Sell、口座方式別挙動
- `docs/specification.md`: 新規エントリー、タブ、折り畳み、表示保証
- `README.md`: 操作方法、確認なしのBuy/Sell、安全上の注意

データ形式、外部API、永続データの変更や移行はない。

## 実装ステップ

1. `src/Models.mqh`へタブ種別と成り行き注文の入力・結果モデルを追加する。注文結果はboolだけでなく、retcode、description、deal、order、result priceを保持できる形にする。
2. `src/Constants.mqh`のレイアウト定数を、固定Chrome、タブバー、タブ本文、可変Statusへ分ける。既存の`PMFormatPrice()`は`SYMBOL_DIGITS`を維持し、表示側が小数桁を落とさない契約を明確にする。
3. `src/ValidationService.mqh`へ、Volume Min/Max/Stepに基づくロット正規化を追加する。エントリーSL/TPはBuyとSellの方向、最新Bid/Ask、Point、Tick Size、Stops Level、Freeze Levelから絶対価格へ変換する。
4. ロット正規化、pointsからの価格変換、固定列用の価格文字列、Status折り返しをUIから分離した純粋関数として実装し、MT5接続なしでテストできる境界を作る。
5. `src/TradeManager.mqh`へ同期的なMarket Entry処理を追加する。注文前に`SetTypeFillingBySymbol()`を設定し、Buy/Sellの結果を`ResultRetcode()`、`ResultDeal()`、`ResultOrder()`、`ResultPrice()`で判定する。
6. Market Entryは既存のTicket単位リトライキューへ追加しない。結果不明時に同じ注文を再送してポジションが重複することを防ぐ。
7. `src/UiPanel.mqh`を、常時表示するタイトルバー、タブバー、選択中のタブ本文、可変Statusの4領域へ再編する。非選択タブは`OBJPROP_TIMEFRAMES=OBJ_NO_PERIODS`、選択タブは`OBJ_ALL_PERIODS`として表示とイベントを切り替える。
8. `Entry`タブへ現在価格、Lotステッパー、SL/TP pointsステッパー、方向別価格プレビュー、Buy/Sellボタンを配置する。注文直前に最新Tickで再計算し、画面プレビューの古い価格をそのまま送らない。
9. `Positions`タブの行を、長文を連結した単一テキストから、幅を保証できる固定列または複数行のコンパクト表示へ変更する。価格用の列幅は`SYMBOL_DIGITS`分を確保し、Ticket列を末尾まで表示する。
10. Position行はPositionsタブが表示されているときだけ生成・更新する。ポジションの収集、選択済みTicketの整理、ページ位置の補正は他タブや折り畳み中も継続する。
11. Statusを固定の単一ラベルから複数行へ変更する。パネル本文幅から1行の上限を求め、全文をStatus行配列へ分割し、行数に応じて背景高とグリップ位置を更新する。
12. 折り畳み状態、直前の選択タブ、展開寸法を`CUiPanel`で保持する。折り畳み中はタイトルと展開ボタン以外を非表示にし、展開ボタンの領域を除いたタイトルバーで既存のドラッグ処理を使う。
13. `tests/PositionManagerPureTests.mq5`へ、volume境界、step丸め、Buy/SellのSL/TP計算、価格桁保持、Status折り返しのテストを追加する。
14. `tests/manual-test-plan.md`へ、表示幅、タブ状態、折り畳みドラッグ、1クリック1注文、取引禁止、閉場、netting/hedgingを追加する。
15. `docs/specification.md`と`README.md`から「新規Buy/Sellは非対象」を削除し、タブ、折り畳み、初期SL/TP、確認なしの注文、安全上の注意、表示仕様を記載する。

## 検証

### コンパイルとPure Tests

Windows上で、リポジトリに存在する`compile.ps1`を使用する。

```powershell
.\scripts\compile.ps1 -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

```powershell
.\scripts\compile.ps1 `
  -MetaEditorPath "C:\Program Files\MetaTrader 5\metaeditor64.exe" `
  -SourcePath ".\tests\PositionManagerPureTests.mq5"
```

Pure TestsをScriptとして実行し、すべてのケースが`[PASS]`になることを確認する。

### 表示確認

- USDJPYでTPを`159.520`にしたポジションを表示し、`TP=159.520`、Profit、Ticketが同時に見えることを確認する。
- 価格桁数の異なる銘柄を混在させ、各銘柄の`SYMBOL_DIGITS`に一致することを確認する。
- `SL clear stopped: trading unavailable (auto trading disabled by client)`と、ticket・retcodeを含む長いメッセージをStatusへ設定し、全文が見えることを確認する。
- パネルを最小幅・最大幅へ変更しても、Position列とStatusが欠落しないことを確認する。
- 6タブを順番に切り替え、非選択タブの部品が表示・反応しないことを確認する。
- 各タブで折り畳みと展開を行い、選択タブ、入力値、位置、幅が維持されることを確認する。
- 折り畳み中にチャートの四隅へドラッグでき、再展開後もチャート外へはみ出さないことを確認する。

### 取引確認

- デモ口座でSL/TPなし、SLのみ、TPのみ、SL/TP両方のBuy/Sellを実行する。
- 1回のクリックに対し、Expertsログの注文要求が1件だけであることを確認する。
- Volume Min、Volume Max、Volume Step境界と、範囲外のロットを確認する。
- Stops Level未満、価格取得不可、Algo Trading無効、閉場、通信断のStatusとログを確認する。
- netting口座とhedging口座の両方で、既存ポジションがある状態のBuy/Sellを確認する。
- タブ非表示または折り畳み中も、Auto Close、Equity Guard、Break Even、Trailingが継続することを確認する。
- `tests/manual-test-plan.md`の既存ケースを再実行し、決済、SL/TP変更、ページング、リサイズに退行がないことを確認する。

## リスク

- 確認なしの誤発注 — BuyとSellを色・ラベルで明確に分け、ボタンの直前にSymbol、Lot、計算済みSL/TPを常時表示する。
- 通信断時の重複発注 — Market Entryは自動再試行せず、結果不明時はポジションと取引履歴の確認を促す。
- netting口座で反対売買が決済または反転になる — READMEとパネルに口座方式依存を記載し、両方式をデモ口座で検証する。
- 現在価格更新による意図しない入力変化 — points距離は固定し、価格プレビューと注文時の絶対価格だけを最新Tickから再計算する。
- 小型化による新たな表示欠け — Position情報を構造化し、最小幅で全フィールドが見えることを受け入れ条件と手動テストに固定する。
- Statusの動的な高さでパネルがチャート外へ出る — Status更新後にPanelHeightと座標制約を再計算する。
- オブジェクト数増加による描画負荷 — 選択中のタブだけを描画し、Position行とStatus行は必要数だけ生成・更新する。
- 時間足変更とタブの表示制御が干渉する — `OBJ_NO_PERIODS`と`OBJ_ALL_PERIODS`の切替を一元化し、時間足変更を手動テストへ含める。
- `src/UiPanel.mqh`の複雑化 — タブ別生成、表示切替、Position描画、Status折り返し、パネル寸法計算を独立した小さなヘルパーへ分ける。
