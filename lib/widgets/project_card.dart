import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/chat_service.dart';
import '../services/supabase_service.dart';

import '../models/message_model.dart';
import '../models/project_model.dart';

import '../utils/project_ui_utils.dart';

class ProjectCard extends StatelessWidget {

  final ProjectModel project;

  final Function(ProjectModel) onEdit;
  final Function(ProjectModel) onDelete;

  final VoidCallback? onChat;

  final bool canEdit;
  final bool isOwner;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onEdit,
    required this.onDelete,
    required this.canEdit,
    required this.isOwner,
    this.onChat,
  });

  static final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    final progress = project.progress;

    final participants =
    project.participantsData.map((p)=>p.fullName).toList();

    final deadline =
    DateFormat.yMMMd(context.locale.toString())
        .format(project.deadline);

    return Card(

      margin: const EdgeInsets.symmetric(horizontal: 12,vertical: 6),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),

      child: InkWell(

        borderRadius: BorderRadius.circular(18),

        onTap: canEdit
            ? () => onEdit(project)
            : null,

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              _buildHeader(context),

              const SizedBox(height: 8),

              _buildLastMessage(context),

              const SizedBox(height: 10),

              if(project.totalTasks > 0)
                _buildProgress(progress,colorScheme),

              const SizedBox(height: 6),

              _buildParticipants(participants),

              const SizedBox(height: 6),

              _buildMeta(context,deadline),

              if(project.attachments.isNotEmpty)
                _buildAttachments(context),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // HEADER
  // ======================================================

  Widget _buildHeader(BuildContext context){

    final colorScheme = Theme.of(context).colorScheme;

    return Row(

      children: [

        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: project.colorObj,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width:10),

        Expanded(
          child: Text(
            project.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        Consumer<AuthProvider>(

          builder:(context,auth,_){

            final userId = auth.userId;

            if(auth.isGuest || userId == null){

              return IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: onChat,
              );
            }

            return StreamBuilder<int>(

              stream: _chatService.getUnreadCount(project.id,userId),

              initialData: 0,

              builder:(context,snapshot){

                final unread = snapshot.data ?? 0;

                return Stack(

                  children: [

                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      onPressed: onChat,
                    ),

                    if(unread>0)

                      Positioned(

                        right: 4,
                        top: 4,

                        child: Container(

                          padding: const EdgeInsets.all(4),

                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),

                          constraints: const BoxConstraints(
                            minWidth:18,
                            minHeight:18,
                          ),

                          child: Text(
                            unread>99
                                ? "99+"
                                : unread.toString(),

                            style: const TextStyle(
                              color: Colors.white,
                              fontSize:10,
                              fontWeight: FontWeight.bold,
                            ),

                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                  ],
                );
              },
            );
          },
        ),

        if(canEdit)

          PopupMenuButton<String>(

            onSelected:(v){
              if(v=="edit") onEdit(project);
              if(v=="delete") onDelete(project);
            },

            itemBuilder:(_)=>[

              PopupMenuItem(
                value:"edit",
                child: Text("project.open".tr()),
              ),

              if(isOwner)

                PopupMenuItem(
                  value:"delete",
                  child: Text(
                    "common.delete".tr(),
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ],
          )
      ],
    );
  }

  // ======================================================
  // LAST MESSAGE PREVIEW
  // ======================================================

  Widget _buildLastMessage(BuildContext context){

    return StreamBuilder<MessageModel?>(

      stream: _chatService.getLastMessage(project.id),

      builder:(context,snapshot){

        final msg = snapshot.data;

        if(msg==null){

          return Text(
            "chat.no_messages".tr(),
            style: TextStyle(
              fontSize:12,
              color: Theme.of(context).colorScheme.outline,
            ),
          );
        }

        final preview = msg.previewText;

        final time =
        DateFormat.Hm().format(msg.createdAt);

        return Row(

          children:[

            Expanded(

              child: Text(
                preview,
                maxLines:1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize:12),
              ),
            ),

            const SizedBox(width:6),

            Text(
              time,
              style: const TextStyle(fontSize:11),
            )
          ],
        );
      },
    );
  }

  // ======================================================
  // PARTICIPANTS AVATARS
  // ======================================================

  Widget _buildParticipants(List<String> participants){

    if(participants.isEmpty) return const SizedBox();

    return SizedBox(

      height:28,

      child: ListView.builder(

        scrollDirection: Axis.horizontal,

        itemCount: participants.length,

        itemBuilder:(context,index){

          final name = participants[index];

          final initials = name.isNotEmpty
              ? name[0].toUpperCase()
              : "?";

          return Padding(

            padding: const EdgeInsets.only(right:6),

            child: CircleAvatar(

              radius:12,

              child: Text(
                initials,
                style: const TextStyle(fontSize:10),
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================================================
  // PROGRESS
  // ======================================================

  Widget _buildProgress(double progress,ColorScheme scheme){

    final p = progress.clamp(0.0,1.0);

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children:[

        LinearProgressIndicator(
          value:p,
          minHeight:6,
          borderRadius: BorderRadius.circular(6),
        ),

        const SizedBox(height:4),

        Text(
          "${(p*100).round()}%",
          style: TextStyle(
            fontSize:11,
            color: scheme.outline,
          ),
        )
      ],
    );
  }

  // ======================================================
  // META
  // ======================================================

  Widget _buildMeta(BuildContext context,String deadline){

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children:[

        Text("${'project.deadline'.tr()}: $deadline"),

        Text(
          "${'project.status'.tr()}: ${project.statusEnum.localizedText(context)}",
        ),
      ],
    );
  }

  // ======================================================
  // ATTACHMENTS
  // ======================================================

  Widget _buildAttachments(BuildContext context){

    final client = Supabase.instance.client;

    return Padding(

      padding: const EdgeInsets.only(top:10),

      child: SizedBox(

        height:48,

        child: ListView.separated(

          scrollDirection: Axis.horizontal,

          itemCount: project.attachments.length,

          separatorBuilder:(_,__)=>const SizedBox(width:8),

          itemBuilder:(context,index){

            final att = project.attachments[index];

            final url = client.storage
                .from(SupabaseService.bucket)
                .getPublicUrl(att.filePath);

            return GestureDetector(

              onTap:() async{

                final uri = Uri.parse(url);

                if(await canLaunchUrl(uri)){

                  await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },

              child: Container(

                width:48,
                height:48,

                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant,
                  ),
                ),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(12),

                  child: att.mimeType.contains("image")

                      ? Image.network(url,fit:BoxFit.cover)

                      : Icon(
                    ProjectUIUtils.getFileIcon(att.mimeType),
                    size:20,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}