import 'dart:typed_data';
import 'package:app/host_helper.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> showImagePickerModal(BuildContext context) async {
  List<AssetEntity> photos = [];
  List<AssetPathEntity> albums = [];
  AssetPathEntity? selectedAlbum;
  bool isLoading = true;
  ValueNotifier<Set<AssetEntity>> selectedPhotosNotifier = ValueNotifier<Set<AssetEntity>>({});

  final PermissionState result = await PhotoManager.requestPermissionExtend();
  if (result.isAuth) {
    albums = await PhotoManager.getAssetPathList(onlyAll: false);

    if (albums.isNotEmpty) {
      selectedAlbum = albums[0];
      photos = await selectedAlbum.getAssetListPaged(
        page: 0,
        size: await selectedAlbum.assetCountAsync,
      );
    }

    isLoading = false;
  } else {
    return;
  }

  // ignore: use_build_context_synchronously
  await showCustomModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    content: StatefulBuilder(
      builder: (context, setState) {
        return Stack(
          children: [
            Column(
              children: [

                Align(
                  alignment: Alignment.topLeft,
                  child: IntrinsicWidth(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          highlightColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          splashFactory: NoSplash.splashFactory,
                        ),
                        child: PopupMenuButton<int>(
                          tooltip: '',
                          constraints: const BoxConstraints.tightFor(height: 400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.grey[200],
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  selectedAlbum?.name ?? 'Выберите альбом',
                                  style: const TextStyle(
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 23),
                            ],
                          ),
                          itemBuilder: (BuildContext context) {
                            return albums.asMap().entries.map((entry) {
                              int index = entry.key;
                              var album = entry.value;
                              return PopupMenuItem<int>(
                                value: index,
                                child: Text(
                                  album.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList();
                          },
                          onSelected: (int index) async {
                            setState(() {
                              selectedAlbum = albums[index];
                              isLoading = true;
                            });
                            List<AssetEntity> newPhotos = await albums[index].getAssetListPaged(
                              page: 0,
                              size: await albums[index].assetCountAsync,
                            );
                            setState(() {
                              photos = newPhotos;
                              isLoading = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                              strokeWidth: 4.0,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : photos.isEmpty
                          ? const Center(child: Text('Нет фотографий'))
                          : Padding(
                              padding: const EdgeInsets.only(left: 5, right: 5),
                              child: GridView.builder(
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 4,
                                  mainAxisSpacing: 4,
                                ),
                                itemCount: photos.length,
                                itemBuilder: (context, index) {
                                  return FutureBuilder<Uint8List?>(
                                    future: photos[index].thumbnailData,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                        return ValueListenableBuilder<Set<AssetEntity>>(
                                          valueListenable: selectedPhotosNotifier,
                                          builder: (context, selectedPhotos, child) {
                                            bool isSelected = selectedPhotos.contains(photos[index]);
                                            bool isVideo = photos[index].type == AssetType.video;

                                            return GestureDetector(
                                              onTap: () {
                                                if (isSelected) {
                                                  selectedPhotosNotifier.value = Set.from(selectedPhotos)..remove(photos[index]);
                                                } else {
                                                  selectedPhotosNotifier.value = Set.from(selectedPhotos)..add(photos[index]);
                                                }
                                              },
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  Image.memory(
                                                    snapshot.data!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                  if (isSelected)
                                                    Container(
                                                      color: Colors.black54,
                                                      child: const Icon(
                                                        Icons.check_circle,
                                                        color: Colors.white,
                                                        size: 30,
                                                      ),
                                                    ),
                                                  if (isVideo)
                                                    const Positioned(
                                                      top: 8,
                                                      left: 8,
                                                      child: Icon(
                                                        Icons.videocam,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      } else if (snapshot.connectionState == ConnectionState.waiting) {
                                        return Container(
                                          width: MediaQuery.sizeOf(context).width,
                                          height: MediaQuery.sizeOf(context).height,
                                          color: Colors.grey[200],
                                        );
                                      } else {
                                        return const Icon(Icons.error);
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                ),

              ],
            ),

            Positioned(
              bottom: 20,
              right: 20,
              child: ValueListenableBuilder<Set<AssetEntity>>(
                valueListenable: selectedPhotosNotifier,
                builder: (context, selectedPhotos, child) {
                  return AnimatedOpacity(
                    opacity: selectedPhotos.isEmpty ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        SizedBox(
                          width: 62,
                          height: 62,
                          child: FloatingActionButton(
                            onPressed: () async {
                              Navigator.pop(context, selectedPhotos.toList());

                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              String? userId = prefs.getString('user_id');

                              await uploadFiles(selectedPhotosNotifier.value.toList(), userId!);
                            },
                            elevation: 0,
                            highlightElevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            backgroundColor: const Color.fromARGB(255, 41, 206, 82),
                            child: const Icon(Icons.check, size: 25, color: Colors.white),
                          ),
                        ),
                        if (selectedPhotos.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(255, 255, 255, 255),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              child: Center(
                                child: Text(
                                  '${selectedPhotos.length}',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
          ],
        );
      },
    ),
  );
}

Future<void> uploadFiles(List<AssetEntity> selectedPhotos, String userId) async {
  for (var photo in selectedPhotos) {
    final file = await photo.file;
    if (file != null) {
      String url_upload = await host_helper('upload');

      final uri = Uri.parse(url_upload);
      final request = http.MultipartRequest('POST', uri)
        ..fields['file_type'] = photo.type.toString()
        ..fields['user_id'] = userId // передача userId
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();

      print("REQ: $request");

      if (response.statusCode == 200) {
        print('Файл успешно загружен: ${photo.title}');
      } else {
        print('Ошибка загрузки файла: ${photo.title}, код ошибки: ${response.statusCode}');
      }
    } else {
      print('Не удалось получить файл для фото: ${photo.title}');
    }
  }
}



Future<void> showCustomModalBottomSheet({
  required BuildContext context,
  required Widget content,
  double heightFactor = 0.85,
  BorderRadius borderRadius = const BorderRadius.vertical(top: Radius.circular(25)),
  Color backgroundColor = Colors.white,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: borderRadius,
    ),
    builder: (BuildContext context) {
      return FractionallySizedBox(
        heightFactor: heightFactor,
        child: content,
      );
    },
  );
}