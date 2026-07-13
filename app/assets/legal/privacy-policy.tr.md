# Gizlilik Politikası ve Aydınlatma Metni

Bu metin, Hayati'nin hangi verileri neden topladığını, bu verilerin nerede tutulduğunu ve sahip olduğunuz seçimleri açıklar. Aynı zamanda 6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamındaki aydınlatma metnidir. Amacımız kulağa etkileyici gelmek değil, uygulamanın gerçekte yaptığıyla karşılaştırılabilir olmaktır. Buradaki bir cümle uygulamanın yapamayacağı bir şeyi vaat ediyorsa, bu bir hatadır ve bunu bize bildirmenizi isteriz.

Sürüm 1. Yürürlük tarihi: 13 Temmuz 2026.

## Veri sorumlusu kimdir

Hayati, burada açıklanan kişisel verilerden sorumlu veri sorumlusu olan [KURUCU/ŞİRKET TÜZEL KİMLİĞİ — kurucu tarafından doldurulacak] tarafından işletilir.

Gizlilikle ilgili konularda bize [İLETİŞİM ADRESİ — kurucu tarafından doldurulacak] üzerinden ulaşabilirsiniz.

## Neyi topluyoruz ve nerede tutuluyor

İlişkinize dair içeriğiniz, Google Cloud Firestore üzerinde, Avrupa Birliği çoklu bölgesinde tutulur. Bu içerik şunları kapsar:

- serbest metinle yazdığınız yansımalarınız ve partnerinizle paylaştığınız cevaplar (her biri en fazla 2000 karakter)
- profiliniz: ilişki durumunuz, soru diliniz ve tonunuz
- çift bilgileri: sizinle partneriniz arasındaki bağ, saat diliminiz ve seriniz
- koç kullanım sayaçları — kaç koç mesajı kullandığınız; mesajların kendisi asla tutulmaz
- abonelik durumunuzun bir kopyası
- davet kayıtları

Bazı hizmet verileri Avrupa Birliği'nde tutulmaz. Her şeyin tek bir yerde olduğunu iddia etmek yerine bunu açıkça söylüyoruz:

- giriş kimlik bilgileriniz — Apple veya Google'dan gelen adınız, e-postanız ve fotoğrafınız ile SMS ile giriş yapıyorsanız telefon numaranız — Google'ın Firebase Authentication hizmetinde tutulur; bu hizmet Avrupa bölgesine sabitlenmemiştir.
- yalnızca yayımlanmış uygulamada toplanan çökme (crash) tanı verileri, Google'ın Crashlytics hizmeti tarafından Avrupa Birliği dışında işlenir. Bu veriler cihaz ve işletim sistemi bilgilerinizi, hata izlerini ve bir kurulum kimliğini içerir. Yansımalarınızı, cevaplarınızı veya koç mesajlarınızı asla içermez.
- uygulama bütünlüğü kontrolü (App Check), isteklerin gerçek uygulamadan geldiğini doğrular; bu doğrulama da Avrupa bölgesine sabitlenmemiştir.

İlişkinize dair içeriğiniz Avrupa Birliği'nde saklanır. Bazı hizmet verileri — giriş kimlik bilgileriniz ve çökme tanı verileri — Google tarafından Avrupa Birliği dışında işlenir. Tüm verilerinizin Avrupa'da olduğunu iddia etmiyoruz, çünkü durum böyle değil.

İçeriğiniz saklanırken şifrelenir (Firestore'un varsayılan bekleyen veri şifrelemesi; anahtarlar Google tarafından yönetilir) ve aktarım sırasında da şifrelenir. Bu, uçtan uca şifreleme değildir ve içeriğinizi okuyamadığımızı iddia etmiyoruz.

## Verilerinizi neden işliyoruz ve hukuki sebebimiz

Her amaç için hukuki sebebi ayrıca belirtiyoruz, çünkü hukuki sebebi gizleyen bir metin gerçek bir aydınlatma değildir.

- Kaydolduğunuz hizmeti yürütmek için — giriş, profiliniz, partnerinizle eşleşme, seriler ve abonelik durumunuz — hukuki sebebimiz, bu işlemenin sizinle olan sözleşmemizi ifa etmek için gerekli olmasıdır. Bunu bir açık rıza talebine sarmayız; hizmetin varlığı için zorunlu olan bir şey için rıza istemek sizi yanıltır.
- Yansımalarınızı, paylaştığınız cevapları ve koç mesajlarınızı — uygulamanın mahrem çekirdeğini — saklamak ve göstermek için hukuki sebebimiz açık rızanızdır. Bu içeriği hassas kabul eder, ihtiyatlı yorumu benimser ve bu özellikler başlamadan önce tek ve açık bir rıza isteriz. Bu rıza gereklidir, çünkü bu içerik hizmetin ta kendisidir; o olmadan birlikte üzerine düşünülecek bir şey kalmaz. Rıza vermezseniz yine de çıkış yapabilir, verilerinizi indirebilir veya hesabınızı doğrudan ve anında silebilirsiniz.
- Verilerinizi Google'ın Avrupa altyapısında barındırmak — ki bu, Türk hukuku kapsamında bir yurt dışına aktarımdır — için hukuki sebebimiz, sözleşmenin ifası için gereklilik ile Kurum'a bildirilen bir standart sözleşmedir. Bu aktarım size bir bildirim olarak sunulur. Açık rızanıza dayanmaz ve mahrem özelliklere ilişkin rızanızı geri almanız bu barındırmayı durdurmaz.

## Verileriniz kimlerle paylaşılır

- Google (Firebase Authentication, Cloud Firestore, Cloud Functions, App Check, Crashlytics), talimatlarımız doğrultusunda ve Google'ın veri işleme koşulları altında veri işler.
- Apple; App Store'u, uygulama içi satın almayı ve Apple ile Giriş'i sağlar. Apple'ın mağaza olarak işlediği veriler bakımından Apple, kendi koşulları altında kendi veri sorumlusu olarak hareket eder.
- RevenueCat, abonelikler bağlandığında abonelik durumunu bizim adımıza işleyecektir. Henüz yapılandırılmamıştır.
- Koç için bir yapay zekâ sağlayıcısı henüz seçilmemiştir. Bir sağlayıcı seçildiğinde, onu güncellenmiş bir metinde adıyla belirtecek, sözleşmeyle konuşmalarınızı modellerini eğitmek için kullanmamasını şart koşacak ve devreye girmeden önce tekrar rızanızı isteyeceğiz. Bugün koç, herhangi bir dış yapay zekâ sağlayıcısına ulaşmaz.

İlişkinize dair içeriğinizi reklam için kullanmayız ve Hayati'de reklam yoktur. Uygulamada bugün herhangi bir analitik veya takip ürünü bulunmamaktadır; ileride böyle bir şey eklersek, bu metne dâhil edilmeden, kendi ayrı ve isteğe bağlı onayıyla gelecektir.

## Hayati'yi cihazınızda gizli tutmak

Hayati'nin gizliliğinin bir kısmı kendi cihazınızdadır; bunu abartmak yerine dürüst sınırlarıyla anlatıyoruz:

- Hayati'yi 6 haneli bir PIN ile kilitleyebilir, isteğe bağlı bir kısayol olarak Face ID veya Touch ID kullanabilirsiniz. Bu yerel bir korumadır: uygulamaya gündelik erişimi engeller, ancak adli düzeyde değildir ve kendi cihaz kimlik bilgilerinize sahip birini alt edemez. SIM kartınıza (SMS kodu için) veya cihaz Apple kimliğinize sahip biri, hesap kurtarma yoluyla içeri girmeye zorlayabilir — bu da sizi çıkışa alır ve PIN'i kaldırır, böylece fark edebileceğiniz bir iz bırakır.
- Sade uygulama simgesi, ana ekranınızda sade bir simge gösterir. Uygulamanın adı simgenin altında görünmeye devam eder; değişen simgenin görüntüsüdür, adı değil.
- Hayati bugün anlık bildirim (push) göndermez. İleride bildirim gönderimi eklenirse, gizli bildirimler ayarı bir bildirimin ne kadarını göstereceğini belirler — yalnızca yeni bir şey geldiğini gösterir, soru veya cevap metnini asla — ve Arapça için varsayılan olarak açıktır.

## Verilerinizi ne kadar süre saklıyoruz

Hayati'de hiçbir şey bir zamanlayıcıyla kendiliğinden sona ermez. Yansımalarınız ve cevaplarınız siz silene kadar kalır.

- Davet kodları oluşturulmalarından 48 saat sonra çalışmayı durdurur; ancak davet kaydının kendisi hesabınız silinene kadar saklanır.
- Hesabınızı silmek, verilerinizin yok edildiği yoldur — ayrı bir sona erme süresi yoktur.
- Koç hiçbir şey saklamaz. Koç konuşmaları yalnızca siz kullanırken cihazınızın belleğinde tutulur ve uygulamayı kapattığınızda ya da çıkış yaptığınızda kaybolur; sunucularımızda veya cihazınızda hiçbir şey saklanmaz.
- Bir mesaj kriz gibi göründüğünde koç sizi profesyonel yardıma yönlendirebilir. Bunun gerçekleştiğine dair hiçbir kayıt tutmayız.

## Haklarınız

6698 sayılı Kanun'un 11. maddesi uyarınca şunları yapabilirsiniz: verilerinizin işlenip işlenmediğini öğrenmek; işlenmişse buna ilişkin bilgi talep etmek; işleme amacını ve amaca uygun kullanılıp kullanılmadığını öğrenmek; verilerinizin yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilmek; eksik veya yanlış işlenmişse düzeltilmesini istemek; silinmesini veya yok edilmesini istemek; düzeltme ve silme işlemlerinin aktarıldığı kişilere bildirilmesini istemek; işlenen verilerin münhasıran otomatik sistemlerle analizi sonucu aleyhinize bir sonuç doğmasına itiraz etmek; ve hukuka aykırı işleme nedeniyle zarara uğrarsanız giderim talep etmek. Bu hakların ikisi doğrudan uygulamaya yerleştirilmiştir:

- Ayarlar'daki "Verilerimi indir", kendi verilerinizin bir kopyasını, uygulama içinde, e-postayla hiçbir şey gönderilmeden verir. Yalnızca sizin verilerinizi kapsar — partnerinizin yazdıklarını asla içermez.
- Ayarlar'daki "Hesabı ve verileri sil", hesabınızı, özel yansımalarınızı ve partnerinizle olan tüm ortak alanı — her cevabın iki tarafını da — kalıcı olarak kaldırır. Bu geri alınamaz. App Store aboneliğini iptal etmez; bunu App Store ayarlarınızdan yönetirsiniz. Partnerinizin daha önce okuduğu veya hatırladığı şeyi geri alamaz. Partneriniz, uygulamayı bir sonraki açışında, sakin bir şekilde ve uygulama içinde ortak alanın kapandığını görecek — nedenini değil — ve kendisine hiçbir anlık bildirim gönderilmeyecektir.

Diğer haklarınız için yukarıdaki adresten bize ulaşabilirsiniz.

## Rızanız ve rızanızı geri almanız

Hayati'de tam olarak tek bir rıza vardır: yansımalarınızın, paylaştığınız cevapların ve koç mesajlarınızın işlenmesine ilişkin rızanız. Toplu onay kutuları ya da var olmayan şeyler için düğmeler yoktur.

Bu rızayı Ayarlar'daki hukuki ekrandan istediğiniz zaman geri alabilirsiniz. Ücretsizdir, tek bir onay gerektirir ve sizden rıza verirkenkinden fazlasını istemez. Rızanızı geri aldığınızda mahrem özellikler duraklar ve bunları kullanmak isterseniz tekrar rıza vermeniz istenir.

Rızanızı geri almanız, daha önce yazdıklarınızı silmez. Saklanan yansımalarınız ve paylaştığınız cevaplar, siz kendiniz silene kadar saklı kalır — rızanızı geri almak, hâlihazırda kayıtlı olan hiçbir şeyi durdurmaz. O içeriğin silinmesini istiyorsanız, geri alma işleminin hemen yanında sunulan "Hesabı ve verileri sil" seçeneğini kullanın.

## Bu metindeki değişiklikler

Bu, sürüm 1'dir. Esaslı bir değişiklik yaparsak — örneğin yapay zekâ sağlayıcısını bağlarsak — bu metni güncelleyecek, sürümünü yükseltecek ve değişen işleme başlamadan önce tekrar rızanızı isteyeceğiz.

## İletişim

Gizliliğinize veya bu metne ilişkin sorularınızı [İLETİŞİM ADRESİ — kurucu tarafından doldurulacak] adresine iletebilirsiniz.
