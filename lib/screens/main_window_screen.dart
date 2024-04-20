import 'package:flutter/widgets.dart';
import 'package:otzaria/helper/shortcuts_list.dart';
import 'package:hive/hive.dart';
import 'package:otzaria/screens/bookmark_screen.dart';
import 'package:otzaria/model/books.dart';
import 'package:otzaria/screens/library_browser.dart';
import 'package:otzaria/screens/settings_screen.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:math';
import 'pdf_book_screen.dart';
import 'text_book_screen.dart';
import 'find_book_screen.dart';
import 'library_search_screen.dart';
import 'package:flutter_settings_screen_ex/flutter_settings_screen_ex.dart';
import 'package:file_picker/file_picker.dart';
import '../model/tabs.dart';
import 'package:permission_handler/permission_handler.dart';
import '../model/bookmark.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

class MainWindowView extends StatefulWidget {
  final ValueNotifier<bool> isDarkMode;
  final ValueNotifier<Color> seedColor;

  const MainWindowView({
    required this.isDarkMode,
    required this.seedColor,
    Key? key,
  }) : super(
          key: key,
        );

  @override
  MainWindowViewState createState() => MainWindowViewState();
}

class MainWindowViewState extends State<MainWindowView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  ValueNotifier<int> selectedIndex = ValueNotifier(0);
  late List<OpenedTab> tabs;
  late TabController tabController = TabController(
      length: tabs.length, vsync: this, initialIndex: max(0, tabs.length - 1));
  final showBooksBrowser = ValueNotifier<bool>(false);
  final showBookSearch = ValueNotifier<bool>(false);
  final showBookmarksView = ValueNotifier<bool>(false);
  final bookSearchfocusNode = FocusNode();
  final FocusScopeNode mainFocusScopeNode = FocusScopeNode();
  late Future<String?> libraryRootPath;
  final List<dynamic> rawBookmarks =
      Hive.box(name: 'bookmarks').get('key-bookmarks') ?? [];
  late List<Bookmark> bookmarks;

  @override
  void initState() {
    () async {
      if (Platform.isAndroid) {
        await Permission.manageExternalStorage.request();
      }
    }();
    WidgetsBinding.instance.addObserver(this);
    tabs = List<OpenedTab>.from(
        ((Hive.box(name: 'tabs').get('key-tabs') ?? []) as List)
            .map((e) => OpenedTab.fromJson(e))
            .toList());
    bookmarks = rawBookmarks.map((e) => Bookmark.fromJson(e)).toList();

    if (Settings.getValue('key-font-size') == null) {
      Settings.setValue('key-font-size', 25.0);
    }
    if (Settings.getValue('key-font-family') == null) {
      Settings.setValue('key-font-family', 'FrankRuhlCLM');
    }

    libraryRootPath = () async {
      // first try to get the library path from settings
      if (Settings.getValue<String>('key-library-path') != null) {
        return Settings.getValue<String>('key-library-path');
        //if faild, ask the user on android to find the path
      } else {
        if (Platform.isAndroid) {
          String? path = await FilePicker.platform.getDirectoryPath();
          if (path != null) {
            Settings.setValue<String>('key-library-path', path);
            return path;
          }
        }
        //on windows/linux, just use the application path
        return '.';
      }
    }();

    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      Hive.box(name: 'tabs').put("key-tabs", tabs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: OrientationBuilder(builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return buildShortcuts();
          } else {
            return Column(children: [
              Expanded(
                child: Row(children: [
                  buildBooksBrowser(),
                  buildBookSearchScreen(),
                  buildBookmarksView(),
                  buildTabBarAndTabView()
                ]),
              ),
              buildNavigationBottomBar(),
            ]);
          }
        }),
      ),
    );
  }

  CallbackShortcuts buildShortcuts() {
    return CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          shortcuts[
              Settings.getValue<String>('key-shortcut-open-book-browser') !=
                      null
                  ? Settings.getValue<String>('key-shortcut-open-book-browser')
                  : 'ctrl+b']!: () {
            showBooksBrowser.value = true;
            showBookSearch.value = false;
          },
          shortcuts[Settings.getValue<String>('key-shortcut-close-tab') != null
              ? Settings.getValue<String>('key-shortcut-close-tab')
              : 'ctrl+w']!: () {
            setState(() {
              closeTab(tabs[tabController.index]);
            });
          },
          shortcuts[
              Settings.getValue<String>('key-shortcut-close-all-tabs') != null
                  ? Settings.getValue<String>('key-shortcut-close-all-tabs')
                  : 'ctrl+x']!: () {
            setState(() {
              tabs.removeRange(0, tabs.length);
              Hive.box(name: 'tabs').put("key-tabs", tabs);
              tabController = TabController(length: tabs.length, vsync: this);
            });
          },
          shortcuts[
              Settings.getValue<String>('key-shortcut-open-book-search') != null
                  ? Settings.getValue<String>('key-shortcut-open-book-search')
                  : 'ctrl+o']!: () {
            showBooksBrowser.value = false;
            showBookSearch.value = true;
            bookSearchfocusNode.requestFocus();
          },
          shortcuts[
              Settings.getValue<String>('key-shortcut-open-new-search') != null
                  ? Settings.getValue<String>('key-shortcut-open-new-search')
                  : 'ctrl+q']!: () {
            setState(() {
              addTab(SearchingTab('חיפוש'));
            });
          },
        },
        child: FocusScope(
          node: mainFocusScopeNode,
          //on android don't autofocus, so keyboard won't show
          autofocus: Platform.isAndroid ? false : true,
          child: ListenableBuilder(
              listenable: selectedIndex,
              builder: (context, child) {
                Widget mainWindow = Container();
                switch (selectedIndex.value) {
                  case (0):
                    mainWindow = buildLibraryBrowser();
                    break;
                  case (1 || 2 || 3):
                    mainWindow = buildTabBarAndTabView();
                    break;
                  case (4):
                    mainWindow = buildSettingsScreen();
                }
                return Row(children: [
                  buildNavigationSideBar(),
                  buildBookmarksView(),
                  mainWindow
                ]);
              }),
        ));
  }

  Widget buildLibraryBrowser() {
    return Expanded(
      child: Container(
          color: Colors.white,
          child: LibraryBrowser(
            onBookClickCallback: openTextBook,
          )),
    );
  }

  Widget buildTabBarAndTabView() {
    if (tabs.isEmpty) {
      return const Expanded(child: Center(child: Text('לא נבחרו ספרים')));
    }
    return Expanded(
      child: NotificationListener<UserScrollNotification>(
        onNotification: (scrollNotification) {
          Future.microtask(() {
            showBooksBrowser.value = false;
            showBookSearch.value = false;
            showBookmarksView.value = false;
          });
          return false; // Don't block the notification
        },
        child: Scaffold(
          appBar: buildTabBar(),
          body: Row(children: [
            Expanded(
              child: buildTabBarView(),
            ),
          ]),
        ),
      ),
    );
  }

  TabBarView buildTabBarView() {
    return TabBarView(
        controller: tabController,
        children: tabs.map((tab) {
          if (tab is PdfBookTab) {
            return PdfBookViewr(
              key: PageStorageKey(tab),
              tab: tab,
              controller: tab.pdfViewerController,
              addBookmarkCallback: addBookmark,
            );
          } else if (tab is TextBookTab) {
            return TextBookViewer(
              tab: tab,
              openBookCallback: addTab,
              data: tab.bookData,
              addBookmarkCallback: addBookmark,
            );
          } else if (tab is SearchingTab) {
            return FutureBuilder(
                future: libraryRootPath,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return TextFileSearchScreen(
                      openBookCallback: addTab,
                      searcher: tab.searcher,
                      libraryRootPath: snapshot.data!,
                    );
                  }

                  return const Center(child: CircularProgressIndicator());
                });
          }
          return const SizedBox.shrink();
        }).toList());
  }

  TabBar buildTabBar() {
    return TabBar(
      controller: tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      tabs: tabs
          .map((tab) => Listener(
                // close tab on middle mouse button click
                onPointerDown: (PointerDownEvent event) {
                  if (event.buttons == 4) {
                    closeTab(tab);
                  }
                },
                child: Tab(
                  child: Row(children: [
                    Text(
                      tab is SearchingTab
                          ? '${tab.title}:  ${tab.searcher.queryController.text}'
                          : tab.title,
                    ),
                    IconButton(
                        onPressed: () {
                          closeTab(tab);
                        },
                        icon: const Icon(Icons.close, size: 10))
                  ]),
                ),
              ))
          .toList(),
    );
  }

  AnimatedSize buildBookSearchScreen() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: ValueListenableBuilder(
        valueListenable: showBookSearch,
        builder: (context, showBookSearch, child) => SizedBox(
          width: showBookSearch ? 300 : 0,
          height: showBookSearch ? null : 0,
          child: child!,
        ),
        child: FutureBuilder(
            future: libraryRootPath,
            builder: (context, snapshot) {
              return snapshot.hasData
                  ? BookSearchScreen(
                      openBookCallback: openBook,
                      closeLeftPaneCallback: closeLeftPanel,
                      focusNode: bookSearchfocusNode,
                      libraryRootPath: snapshot.data!)
                  : const Center(child: CircularProgressIndicator());
            }),
      ),
    );
  }

  AnimatedSize buildBooksBrowser() {
    return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: ValueListenableBuilder(
            valueListenable: showBooksBrowser,
            builder: (context, showBooksBrowser, child) => SizedBox(
                  width: showBooksBrowser ? 300 : 0,
                  height: showBooksBrowser ? null : 0,
                  child: child!,
                ),
            child: LibraryBrowser(
              onBookClickCallback: openTextBook,
            )));
  }

  AnimatedSize buildBookmarksView() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: ValueListenableBuilder(
          valueListenable: showBookmarksView,
          builder: (context, showBookmarksView, child) => SizedBox(
                width: showBookmarksView ? 300 : 0,
                height: showBookmarksView ? null : 0,
                child: child!,
              ),
          child: BookmarkView(
            openBookmarkCallBack: openBook,
            bookmarks: bookmarks,
            closeLeftPaneCallback: closeLeftPanel,
          )),
    );
  }

  Widget buildSettingsScreen() {
    return Expanded(
      child: MySettingsScreen(
          isDarkMode: widget.isDarkMode, seedColor: widget.seedColor),
    );
  }

  SizedBox buildNavigationSideBar() {
    return SizedBox.fromSize(
      size: const Size.fromWidth(80),
      child: NavigationRail(
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.library_books),
              label: Text('ספריה'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.menu_book),
              label: Text('קריאה'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.bookmark),
              label: Text('סימניות'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.search),
              label: Text('חיפוש'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.settings),
              label: Text('הגדרות'),
            ),
          ],
          selectedIndex: selectedIndex.value,
          onDestinationSelected: (int index) {
            setState(() {
              selectedIndex.value = index;
              switch (index) {
                case 2:
                  _openBookmarksScreen();
                case 3:
                  showBookSearch.value = false;
                  showBooksBrowser.value = false;
                  _openSearchScreen();
              }
            });
          }),
    );
  }

  NavigationBar buildNavigationBottomBar() {
    return NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: 'ספרייה',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books),
            label: 'איתור ספר',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'חיפוש',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark),
            label: 'סימניות',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'הגדרות',
          ),
        ],
        selectedIndex: selectedIndex.value,
        onDestinationSelected: (int index) {
          setState(() {
            selectedIndex.value = index;
            switch (index) {
              case 0:
                showBookSearch.value = false;
                showBooksBrowser.value = !showBooksBrowser.value;
              case 1:
                showBooksBrowser.value = false;
                showBookSearch.value = !showBookSearch.value;
              case 2:
                showBookSearch.value = false;
                showBooksBrowser.value = false;
                _openSearchScreen();
              case 3:
                showBookSearch.value = false;
                showBooksBrowser.value = false;
                _openBookmarksScreen();

              case 4:
                _openSettingsScreen();
            }
          });
        });
  }

  void openBook(String path, int index) {
    if (path.endsWith('.pdf')) {
      addTab(PdfBookTab(path, index));
    } else {
      addTab(TextBookTab(title: utils.getTitleFromPath(path), index));
    }
  }

  void openTextBook(Book book, int index) {
    addTab(TextBookTab(0, title: book.title));
    selectedIndex.value = 1;
  }

  void addTab(OpenedTab tab) {
    setState(() {
      int newIndex = tabController.length == 0 ? 0 : tabController.index + 1;
      tabs.insert(newIndex, tab);
      tabController = TabController(length: tabs.length, vsync: this);
      tabController.index = newIndex;
    });
    Hive.box(name: 'tabs').put("key-tabs", tabs);
  }

  void closeTab(OpenedTab tab) {
    setState(() {
      if (tabs.isNotEmpty) {
        int newIndex = tabs.indexOf(tab) <= tabController.index
            ? max(0, tabController.index - 1)
            : tabController.index;
        tabs.remove(tab);
        tabController = TabController(
            length: tabs.length, vsync: this, initialIndex: newIndex);
      }
    });
    Hive.box(name: 'tabs').put("key-tabs", tabs);
  }

  void showLibrary() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => LibraryBrowser(
                  onBookClickCallback: openTextBook,
                )));
  }

  void _openSettingsScreen() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => MySettingsScreen(
                isDarkMode: widget.isDarkMode, seedColor: widget.seedColor)));
    setState(() {});
  }

  void _openSearchScreen() async {
    addTab(SearchingTab('חיפוש'));
  }

  void _openBookmarksScreen() {
    showBookmarksView.value = !showBookmarksView.value;
  }

  void addBookmark(
      {required String ref, required String title, required int index}) {
    bookmarks.add(Bookmark(ref: ref, title: title, index: index));
    // write to disk
    Hive.box(name: 'bookmarks').put('key-bookmarks', bookmarks);
    // notify user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הסימניה נוספה בהצלחה'),
        ),
      );
    }
  }

  void closeLeftPanel() {
    showBooksBrowser.value = false;
    showBookSearch.value = false;
    showBookmarksView.value = false;
  }
}
