import 'package:flutter/material.dart';
import 'package:otzaria/models/library.dart';
import 'package:expandable/expandable.dart';
import 'package:otzaria/models/books.dart';
import 'dart:math';

class HeaderItem extends StatelessWidget {
  final Category category;

  const HeaderItem({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(category.title,
          style: TextStyle(
            fontSize: 20,
            color: Theme.of(context).colorScheme.secondary,
          )),
    );
  }
}

class CategoryGridItem extends StatelessWidget {
  final Category category;
  final VoidCallback onCategoryClickCallback;

  const CategoryGridItem({
    Key? key,
    required this.category,
    required this.onCategoryClickCallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCategoryClickCallback,
      child: Card(
          child: SingleChildScrollView(
        child: ExpandablePanel(
          theme: ExpandableThemeData(
              headerAlignment: ExpandablePanelHeaderAlignment.center,
              tapBodyToExpand: false,
              tapHeaderToExpand: false,
              hasIcon: category.shortDescription != '' ? true : false,
              iconPlacement: ExpandablePanelIconPlacement.right,
              alignment: Alignment.center,
              expandIcon: Icons.info_outline,
              collapseIcon: Icons.keyboard_arrow_up,
              iconSize: 12),
          header: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                category.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          collapsed: const SizedBox.shrink(),
          expanded: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              category.shortDescription,
              style: TextStyle(
                  fontSize: 14, color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ),
      )),
    );
  }
}

class BookGridItem extends StatelessWidget {
  final Book book;
  final VoidCallback onBookClickCallback;

  const BookGridItem({
    Key? key,
    required this.book,
    required this.onBookClickCallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onBookClickCallback,
        child: Card(
            child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ExpandablePanel(
            theme: ExpandableThemeData(
                headerAlignment: ExpandablePanelHeaderAlignment.center,
                tapBodyToExpand: false,
                tapHeaderToExpand: false,
                hasIcon: book.heShortDesc != null && book.heShortDesc != ''
                    ? true
                    : false,
                iconPlacement: ExpandablePanelIconPlacement.right,
                alignment: Alignment.center,
                expandIcon: Icons.info_outline,
                collapseIcon: Icons.keyboard_arrow_up,
                iconSize: 15),
            header: ListTile(
              title: Text(
                book.title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                  (book.author == "" || book.author == null)
                      ? ''
                      : ('${book.author!} ${book.pubDate ?? ''}'),
                  style: const TextStyle(fontSize: 14)),
              isThreeLine: true,
              trailing: book is TextBook
                  ? null
                  : SizedBox.fromSize(
                      size: const Size.fromWidth(64),
                      child: ClipRect(
                        child: Builder(builder: (context) {
                          final pdfbook = book as PdfBook;
                          return FutureBuilder(
                            future: pdfbook.thumbnail,
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return snapshot.data!;
                              } else if (snapshot.hasError) {
                                return Text(snapshot.error.toString());
                              } else {
                                return const Icon(Icons.picture_as_pdf);
                              }
                            },
                          );
                        }),
                      ),
                    ),
            ),
            collapsed: const SizedBox.shrink(),
            expanded: Text(
              book.heShortDesc ?? '',
              style: TextStyle(
                  fontSize: 14, color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        )));
  }
}

class MyGridView extends StatelessWidget {
  final Future<List<Widget>> items;

  const MyGridView({Key? key, required this.items}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return FutureBuilder(
            future: items,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return GridView.count(
                  //max number of items per row is 5 and min is 2
                  crossAxisCount: max(2, min(constraints.maxWidth ~/ 200, 5)),
                  shrinkWrap: true,
                  childAspectRatio: 2.5,
                  physics: const ClampingScrollPhysics(),
                  children: snapshot.data!,
                );
              }
              return const Center(child: CircularProgressIndicator());
            });
      },
    );
  }
}