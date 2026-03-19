# Rapid iOSアプリ アーキテクチャ概要

## 1. システム概要 (System Overview)

本アプリ「Rapid」は、iOS向けのネイティブマッチング・コミュニケーションアプリであり、ユーザー同士がロケーション（場所）や募集を通じてつながり、メッセージやボイスチャット等で交流できる基盤を提供します。

### 主な機能
- **認証・アカウント連携**: メールアドレス/ソーシャルログイン、外部アカウント機能（Apple / Google / LINE）
- **プロフィール機能**: プロフィール画像の表示・編集（TUS、クロップ）、各種ステータスやMBTI、趣味などの管理、本人確認機能（書類提出とVision API審査連携）
- **ホーム・募集機能**: マップや地点情報を元にした「募集（アクティビティ）」の一覧・作成
- **コミュニケーション（Chat / Voice Chat）**: リアルタイムチャット、Supabaseによる各種Push通知、SkyWay等を想定したボイスチャット/ビデオ通話
- **マネタイズ (Monetization)**: RevenueCatを利用したプレミアムサブスクリプション（機能解放）およびポイント（都度チャージ）購入

### 技術スタック
- **フロントエンド（iOS）**: Swift, SwiftUI, Combine (リアクティブ・イベント処理)
- **非同期通信・状態管理**: `async/await`, `@EnvironmentObject`, `@StateObject` 等
- **データ管理/認証・BaaS**: Supabase (PostgreSQL, PostgREST, Auth, Storage, Realtime)
- **課金基盤**: RevenueCat (Purchases SDK)
- **その他主要ライブラリ**:
  - `SDWebImageSwiftUI`: プロフィール画像をはじめとする大容量メディアの非同期ダウンロードおよびキャッシュ処理
  - `Lottie`: 各種アニメーション (募集カード等での演出処理)
  - `TUS` プロトコル基盤: 本人確認書類等の画像ストリームアップロード
  - `Google Places API`: スポット検索、ロケーション連携

---

## 2. アプリの基本アーキテクチャ (MVVMパターン)

プロジェクト全体として、データ表現の **Model**、SwiftUIによる宣言的UI **View**、そしてビジネスロジックを管理しViewに状態を公開する **ViewModel** の3層構造（MVVM）によって責務が明確に分離されています。

- **Model 層** (`/Model`)
  - DBスキーマに対応したデータ構造。`RapidUser`、`UserProfileImage`、`Recruitment` など、Supabaseや独自のAPIから取得する素のエンティティデータを定義しています。
  - カスタムエンコード/デコード処理も実装され、データのコンテナとして機能します。

- **View 層** (`/View`)
  - SwiftUIの `View` プロトコルによるUI構築の責務を持ちます。
  - `RecruitmentView`、`ChatView`、`ProfileView` などの主要な大画面と、その内部で使われる再利用可能なコンポーネント（カードやヘッダーなど）にフォルダが分けられています。
  - 原則としてView自身は直接バックエンドと通信せず、ViewModel を `EnvironmentObject` や `StateObject` として参照し、UIの状態（State）を同期させます。

- **ViewModel 層** (`/ViewModel`)
  - `ProfileViewModel` や `ChatViewModel` 等、各主要画面ごとに配置された状態管理者（`ObservableObject`）です。
  - UIからイベント（ボタンが押される、表示される等）を受け取り、後述の `SupabaseManager` や `HttpClient` などのインフラストラクチャサービスを呼び出し、DB更新や外部API連携を実行。
  - 処理結果を `@Published` プロパティに反映させることで、UI（View）の再描画を透過的に発火させます。

---

## 3. バックエンド・インフラストラクチャ連携

外部サーバー及びBaaSとの通信には、主に2つの抽象レイヤーが存在し、コードの重複を防ぎ保守性を確保しています。

- **`SupabaseManager.swift` (BaaS呼び出しの集約)**
  - Supabaseクライアントシングルトンとして機能。
  - セッション取得、DBクエリ(`profile_images` や `users` テーブルなど)、Storageからの署名付きURL生成などのロジックを集約しています。
  - 直近ではプロフィールの画像順序（`imageIndex`）の担保や、DBに保存されたパスからURLを構成する処理（`fetchProfileImagesWithURLs` 等）もここで一元管理されています。

- **`HttpClient` と独自プロキシ・マイクロサービス連携** (`/Library/Http`)
  - 独自のVercel/EC2サーバーに対してAPIリクエスト（メタデータ保存や審査等のポストプロセス用）を送るためのクライアント。
  - 画像のレジュームアップロード（TUS通信）や、Cloud Run/Vision API連携への橋渡し（認証付きのリクエスト処理）に使用されています。

---

## 4. サブスクリプションと課金 (RevenueCat実装)

iOSアプリ内課金とサブスクリプションは、RevenueCatを通じて簡略かつ安定して管理されています。
実装は主に `/View/Utils` 内のペイウォール画面と `ProfileViewModel` 内の処理が担当しています。

- **サブスクリプション (Premiumプラン)**
  - `PremiumPayWallView`: `premium-1-monthly` などの識別子をもつ `Offering` (提供パッケージ) をRevenueCatから取得し表示します。
  - `ProfileViewModel` の `fetchSubscriptionStatus()` にて `Rapid Premium` （Entitlement）の有効性を確認し、`isPremium` フラグを反映させます。
  
- **都度課金 (Point購入)**
  - `PointPurchasePayWallView`: ポイント残高チャージ用。`rapid.60_point` 等の非継続型パッケージの Identifier をハードコード検索で安全に抽出し、購入後に自身のDB（ProfileViewModelの `addPoints` メソッド等）へ反映させます。
  - 購入履歴機能: `Purchases.shared.getCustomerInfo` から `nonSubscriptionTransactions` を引き出し、過去の課金実績を `ProfileSettingPointPurchaseHistoryView` 上で列挙できる構造を構築しています。

---

## 5. 画像・メディア管理

- **画像の高速描画**:
  URLベースの画像はすべて `SDWebImageSwiftUI` （`WebImage`等）を経由して描画され、ViewModel内で `SDWebImagePrefetcher` を使い表示前からメモリキャッシュに事前に読み込ませる仕組みが組み込まれています。

- **安定したアップロードとメタ管理**:
  プロフィール画像や本人確認時のID画像等のアップロードは、以下の2段階を踏みます。
  1. `HttpClient` 経由でプロキシサーバー（Vercel）へ **画像情報(メタデータ)** を登録。
  2. メタデータに対応するUUIDへ、画像のバイナリデータを **TUSプロトコル**（分割/レジューム可能な安全な送信手順）にてストリームアップロード。
  この仕組みにより、大容量ファイル送信時の切断対策とバックエンド側（Vision API等）での審査連動を確立しています。

---

## 6. ディレクトリツリー（主要構造）

\`\`\`
Rapid/
 ┣ AppDelegate.swift / RapidApp.swift # エントリーポイントおよび初期化処理
 ┣ Model/              # DBテーブル定義やAPIリクエスト/レスポンス構造体
 ┣ ViewModel/          # 各画面の状態（@Published）やビジネスロジック群
 ┃  ┣ Home/
 ┃  ┃  ┣ ProfileViewModel.swift
 ┃  ┃  ┣ ChatViewModel.swift  等
 ┃  ┗ ...
 ┣ View/               # SwiftUI ビュー定義
 ┃  ┣ Home/            # メイン画面（Home, Chat, Profile）
 ┃  ┣ Utils/           # ペイウォール (PremiumPayWallView等), ローディングなどの共通UI
 ┃  ┗ ...
 ┣ Library/            # クライアント内部ミドルウェア
 ┃  ┣ Supabase/        # Supabase通信の制御 (SupabaseManager.swift)
 ┃  ┣ Http/            # TUSアップロード処理やプロキシ通信クライアント
 ┃  ┗ Network/         # 汎用的な通信・接続確認ミドルウェア等
 ┗ Extensions/         # Viewモディファイア (例: .skelton()) や 組み込み型の拡張
\`\`\`
