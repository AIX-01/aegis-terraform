##############################################
# EFS (Qdrant Persistent Storage)
##############################################

resource "aws_efs_file_system" "qdrant" {
  encrypted        = true
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode

  tags = { Name = "${var.project_name}-qdrant-efs" }
}

# ── Mount Targets (one per private subnet) ───

resource "aws_efs_mount_target" "qdrant" {
  count = length(aws_subnet.private)

  file_system_id  = aws_efs_file_system.qdrant.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# ── Access Point ─────────────────────────────

resource "aws_efs_access_point" "qdrant" {
  file_system_id = aws_efs_file_system.qdrant.id

  root_directory {
    path = "/qdrant/storage"

    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = { Name = "${var.project_name}-qdrant-ap" }
}
